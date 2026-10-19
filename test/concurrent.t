#!/usr/bin/env bash

source test/init

real_ys=$(
  PKIO_CONFIG_MK='' \
    make --no-print-directory -s -f "$ROOT/Makefile" ys
)
real_ys=${real_ys##*$'\n'}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake_root=$tmp/pkio
mkdir -p "$fake_root" "$tmp/makes" "$tmp/home/.cache/makes" \
  "$tmp/config" "$tmp/first" "$tmp/second" "$tmp/sync"
for dir in etc share util; do
  ln -s "$ROOT/$dir" "$fake_root/$dir"
done
touch "$tmp/makes/rg.mk" "$tmp/makes/node.mk"

cat > "$fake_root/Makefile" <<'EOF'
MAKES := $(PKIO_TEST_TMP)/makes
ifdef PKIO_CONFIG_MK
include $(PKIO_CONFIG_MK)
endif

pkio-setup:
	@"$(PKIO_TEST_TMP)/barrier" setup

pkio-env:
	@echo "PKIO_NONO=$(PKIO_TEST_TMP)/nono"
	@echo "PKIO_NONO_OPTS='$(PKIO-NONO-OPTS)'"
	@echo "PKIO_CMD_ARGS='$(PKIO-CMD-ARGS)'"

ys:
	@echo "$(PKIO_TEST_TMP)/ys"
EOF

# Hold both launches at the points where shared CLI/config files raced.
cat > "$tmp/barrier" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch "$PKIO_TEST_TMP/sync/$1.$PKIO_TEST_LABEL"
for ((attempt = 0; attempt < 200; attempt++)); do
  if [[ -e $PKIO_TEST_TMP/sync/$1.first &&
        -e $PKIO_TEST_TMP/sync/$1.second ]]; then
    exit 0
  fi
  sleep 0.05
done
echo "Timed out waiting for concurrent $1" >&2
exit 1
EOF

cat > "$tmp/ys" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
"$PKIO_TEST_TMP/barrier" convert
exec "$PKIO_TEST_REAL_YS" "$@"
EOF

cat > "$tmp/nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -f "$PKIO_CONFIG_MK"
printf '%s\n' "$PKIO_CONFIG_MK" > \
  "$PKIO_TEST_TMP/config.$PKIO_TEST_LABEL"
printf '%s\n' "$@" > "$PKIO_TEST_TMP/args.$PKIO_TEST_LABEL"
exit "${PKIO_TEST_EXIT:-0}"
EOF
chmod +x "$tmp/barrier" "$tmp/ys" "$tmp/nono"

export HOME=$tmp/home
export PKIO_ROOT=$fake_root
export PKIO_CONFIG=$tmp/config
export PKIO_CACHE=$tmp/cache
export PKIO_TEST_TMP=$tmp
export PKIO_TEST_REAL_YS=$real_ys
unset NONO_CAP_FILE PKIO_CONFIG_MK PKIO_GH_TOKEN_FILE

PKIO_TEST_LABEL=first "$ROOT/bin/pkio" -C "$tmp/first" \
  --rw="$tmp/first-grant/" codex > "$tmp/first.log" 2>&1 &
first_pid=$!
PKIO_TEST_LABEL=second "$ROOT/bin/pkio" -C "$tmp/second" \
  --rw="$tmp/second-grant/" opencode > "$tmp/second.log" 2>&1 &
second_pid=$!

rc=0
wait "$first_pid" || { rc=$?; diag "$(cat "$tmp/first.log")"; }
ok $rc "concurrent Codex launch succeeds"
rc=0
wait "$second_pid" || { rc=$?; diag "$(cat "$tmp/second.log")"; }
ok $rc "concurrent OpenCode launch succeeds"

first_config=$(cat "$tmp/config.first")
second_config=$(cat "$tmp/config.second")
if [[ $first_config != "$second_config" ]]; then rc=0; else rc=1; fi
ok $rc "concurrent launches use separate configuration files"

for label in first second; do
  if [[ $label == first ]]; then program=codex; else program=opencode; fi
  args=$(cat "$tmp/args.$label")
  like "$args" "/etc/cmd/$program/profile.json" \
    "$program launch retains its own profile"
  like "$args" "$tmp/$label-grant/" \
    "$program launch retains its own CLI grant"
  if [[ $label == first ]]; then other=second; else other=first; fi
  unlike "$args" "$tmp/$other-grant/" \
    "$program launch excludes the other CLI grant"
  config=$(cat "$tmp/config.$label")
  if [[ ! -e ${config%/*} ]]; then rc=0; else rc=1; fi
  ok $rc "$program launch removes its temporary directory on exit"
done

# Both barriers are already open for these sequential cleanup checks.
output=$(PKIO_TEST_LABEL=first "$ROOT/bin/pkio" -C "$tmp/first" \
  --show-config codex)
like "$output" '/etc/cmd/codex/profile.json' \
  "show-config prints its configuration before cleanup"

rc=0
PKIO_TEST_LABEL=first PKIO_TEST_EXIT=42 "$ROOT/bin/pkio" \
  -C "$tmp/first" codex > "$tmp/failure.log" 2>&1 || rc=$?
is "$rc" 42 "cleanup preserves the program exit status"
config=$(cat "$tmp/config.first")
if [[ ! -e ${config%/*} ]]; then rc=0; else rc=1; fi
ok $rc "failed launch removes its temporary directory"

remaining=$(find "$PKIO_CACHE/local/tmp" -mindepth 1 -print)
is "$remaining" '' "no invocation directories remain after all exits"

done-testing
