#!/usr/bin/env bash

source test/init

pkio=$ROOT/bin/pkio
real_nono=$(
  PKIO_CONFIG_MK='' \
    make --no-print-directory -s -f "$ROOT/Makefile" \
    shell CMD='command -v nono'
)
real_ys=$(
  PKIO_CONFIG_MK='' \
    make --no-print-directory -s -f "$ROOT/Makefile" ys
)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake_root=$tmp/pkio
fake_makefile=$fake_root/Makefile
stub_nono=$tmp/nono
cwd_file=$tmp/child-cwd
args_file=$tmp/nono-args
home_dir=$tmp/home
config_dir=$tmp/config
main_repo=$tmp/main-repo
worktree=$tmp/worktree\ with\ spaces

mkdir -p "$fake_root" "$home_dir" "$config_dir"
ln -s "$ROOT/etc" "$fake_root/etc"
ln -s "$ROOT/share" "$fake_root/share"
ln -s "$ROOT/util" "$fake_root/util"

cat > "$fake_makefile" <<'EOF'
ifdef PKIO_CONFIG_MK
-include $(PKIO_CONFIG_MK)
endif

PKIO-NONO-OPTS += --allow-cwd
PKIO-NONO-OPTS += $(PKIO_NONO_OPTS_EXTRA)

.PHONY: pkio-setup pkio-env ys

pkio-setup:
	@true

pkio-env:
	@echo "PKIO_NONO=$(PKIO_TEST_NONO)"
	@echo "PKIO_NONO_CMD='wrap'"
	@echo "PKIO_NONO_OPTS='$(PKIO-NONO-OPTS)'"
	@echo "PKIO_CMD_ARGS='$(PKIO-CMD-ARGS)'"

ys:
	@echo "$(PKIO_TEST_YS)"
EOF

cat > "$stub_nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$PWD" > "$PKIO_TEST_CWD_FILE"
printf '%s\0' "$@" > "$PKIO_TEST_ARGS_FILE"
EOF
chmod +x "$stub_nono"

git init -q "$main_repo"
git -C "$main_repo" config user.email test@example.com
git -C "$main_repo" config user.name "pkio test"
echo tracked > "$main_repo/tracked"
git -C "$main_repo" add tracked
git -C "$main_repo" commit -qm initial
git -C "$main_repo" worktree add -qb test-worktree "$worktree"

export HOME=$home_dir
export PKIO_ROOT=$fake_root
export PKIO_CONFIG=$config_dir
export PKIO_CACHE=$tmp/cache
export PKIO_TEST_NONO=$stub_nono
export PKIO_TEST_YS=$real_ys
export PKIO_TEST_CWD_FILE=$cwd_file
export PKIO_TEST_ARGS_FILE=$args_file
unset NONO_CAP_FILE PKIO_CONFIG_MK

load-capture() {
  IFS= read -r -d '' child_cwd < "$cwd_file" || true
  mapfile -d '' -t nono_args < "$args_file"
  separator=
  local i
  for i in "${!nono_args[@]}"; do
    if [[ ${nono_args[$i]} == -- ]]; then
      separator=$i
      break
    fi
  done
}

has-arg() {
  local expected=$1
  shift
  local arg
  for arg in "$@"; do
    [[ $arg != "$expected" ]] || return 0
  done
  return 1
}

has-pair() {
  local expected_flag=$1 expected_value=$2
  shift 2
  local -a args=("$@")
  local i
  for ((i = 0; i + 1 < ${#args[@]}; i++)); do
    if [[ ${args[$i]} == "$expected_flag" &&
          ${args[$((i + 1))]} == "$expected_value" ]]; then
      return 0
    fi
  done
  return 1
}

run-editor() {
  local editor=$1
  shift
  rm -f "$cwd_file" "$args_file"
  (
    cd "$worktree" || exit
    "$pkio" "$editor" "$@"
  ) >/dev/null 2>&1
  load-capture
}

for editor in code code-insiders; do
  run-editor "$editor" .
  is "$child_cwd" "$worktree" \
    "$editor child preserves caller worktree"

  if has-arg --allow-cwd "${nono_args[@]}"; then rc=0; else rc=1; fi
  ok $rc "$editor invocation enables cwd access"

  if has-pair --allow "$main_repo/.git" "${nono_args[@]}"; then
    rc=0
  else
    rc=1
  fi
  ok $rc "$editor linked worktree retains main repository git access"

  if [[ -n $separator ]]; then rc=0; else rc=1; fi
  ok $rc "$editor nono invocation contains command separator"
  program_args=("${nono_args[@]:$((separator + 1))}")
  is "${#program_args[@]}" 4 \
    "$editor relative launch preserves the complete argument vector"
  is "${program_args[0]}" "$editor" \
    "$editor relative launch executes the requested editor"
  is "${program_args[1]}" --no-sandbox \
    "$editor relative launch preserves the Chromium sandbox flag"
  is "${program_args[2]}" --disable-gpu \
    "$editor relative launch preserves the software rendering flag"
  is "${program_args[3]}" . \
    "$editor relative dot target remains in the caller worktree"

  run-editor "$editor" "$worktree"
  program_args=("${nono_args[@]:$((separator + 1))}")
  is "${#program_args[@]}" 4 \
    "$editor absolute launch passes a spaced path as one argument"
  is "${program_args[3]}" "$worktree" \
    "$editor absolute target remains unchanged"

  profile_output=$(
    cd "$worktree" || exit
    "$real_nono" wrap --dry-run \
      --profile "$ROOT/etc/cmd/$editor/profile.json" \
      --allow-cwd -- /usr/bin/pwd 2>&1
  )
  if grep -F "r+w  $worktree (dir)" <<< "$profile_output" >/dev/null; then
    rc=0
  else
    rc=1
  fi
  ok $rc "$editor profile grants the exact spaced worktree read-write"

  for capability in \
    "r+w  /dev/ptmx (file)" \
    "r   /etc/fonts (dir)" \
    "r   /var/cache/fontconfig (dir)" \
    "r   /etc/passwd (file)" \
    "r   /etc/shells (file)"
  do
    if grep -F "$capability" <<< "$profile_output" >/dev/null; then
      rc=0
    else
      rc=1
    fi
    ok $rc "$editor effective profile includes $capability"
  done

  broad_grant=false
  for ((i = 0; i < separator; i++)); do
    [[ ${nono_args[$i]} == --allow ]] || continue
    case ${nono_args[$((i + 1))]} in
      /|"$HOME"|"$tmp"|"$main_repo") broad_grant=true ;;
    esac
  done
  if $broad_grant; then rc=1; else rc=0; fi
  ok $rc "$editor runner adds no broad filesystem or repository grant"
done

done-testing
