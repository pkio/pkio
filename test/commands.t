#!/usr/bin/env bash

source test/init

pkio=$ROOT/bin/pkio

# Set up a temp directory for test isolation
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"

export PKIO_ROOT=$ROOT
export PKIO_CONFIG=$tmp/config
export PKIO_CACHE=$tmp/cache
export HOME=$tmp/home
unset NONO_CAP_FILE PKIO_GH_TOKEN_FILE GH_TOKEN GH_PROMPT_DISABLED
unset GH_NO_UPDATE_NOTIFIER GH_CONFIG_DIR

save_dir=$PWD


# --help prints usage info
output=$("$pkio" --help)
ok $? "--help exits successfully"
like "$output" "pkio - Project Kernel Isolation Orchestrator" \
  "--help shows program name"
like "$output" "Usage:" \
  "--help shows usage line"
like "$output" "--config" \
  "--help mentions --config flag"


# --list shows available programs
output=$("$pkio" --list)
ok $? "--list exits successfully"
like "$output" "claude" \
  "--list includes claude"
like "$output" "opencode" \
  "--list includes opencode"
like "$output" "code-insiders" \
  "--list includes code-insiders"
like "$output" "  code" \
  "--list includes code"


# --show-config includes opencode defaults
output=$("$pkio" --show-config opencode)
ok $? "--show-config opencode exits successfully"
like "$output" "--profile opencode" \
  "--show-config opencode includes opencode profile"

# --show-config includes native VS Code defaults
output=$("$pkio" --show-config code)
ok $? "--show-config code exits successfully"
pkio_root_re='[$][(]PKIO_ROOT[)]'
like "$output" "--profile $pkio_root_re/etc/cmd/code/profile.json" \
  "--show-config code includes native profile"
like "$output" "--no-sandbox" \
  "--show-config code disables nested Chromium sandbox"
like "$output" "--disable-gpu" \
  "--show-config code uses software rendering"
unlike "$output" "/var/lib/snapd" \
  "--show-config code excludes snap data"
unlike "$output" "--read /snap" \
  "--show-config code excludes the snap mount"
printf '%s\n' "$output" > "$tmp/code-config.mk"
output=$(PKIO_PROGRAM=code \
  PKIO_CONFIG_MK=$tmp/code-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
like "$output" "PKIO_NONO_CMD='wrap'" \
  "pkio-env code uses nono wrap"

# --show-config includes native VS Code Insiders defaults
output=$("$pkio" --show-config code-insiders)
ok $? "--show-config code-insiders exits successfully"
like "$output" "--profile $pkio_root_re/etc/cmd/code-insiders/profile.json" \
  "--show-config code-insiders includes native profile"
like "$output" "--no-sandbox" \
  "--show-config code-insiders disables nested Chromium sandbox"
like "$output" "--disable-gpu" \
  "--show-config code-insiders uses software rendering"
unlike "$output" "/var/lib/snapd" \
  "--show-config code-insiders excludes snap data"
printf '%s\n' "$output" > "$tmp/code-insiders-config.mk"
output=$(PKIO_PROGRAM=code-insiders \
  PKIO_CONFIG_MK=$tmp/code-insiders-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
like "$output" "PKIO_NONO_CMD='wrap'" \
  "pkio-env code-insiders uses nono wrap"

home_re='[$]HOME'
check-agent-profile() {
  local profile=$1 editor=$2
  like "$profile" '"claude_code_linux"' \
    "$editor profile includes Claude runtime state"
  like "$profile" '"claude_cache_linux"' \
    "$editor profile includes Claude cache state"
  like "$profile" '"vscode_linux"' \
    "$editor profile includes Claude's VS Code permissions"
  like "$profile" '"node_runtime"' \
    "$editor profile includes agent tool runtimes"
  like "$profile" "$home_re/.claude" \
    "$editor profile shares Claude credentials and state"
  like "$profile" "$home_re/.cache/claude" \
    "$editor profile includes Claude cache"
  like "$profile" "$home_re/.local/state/claude/locks" \
    "$editor profile includes Claude locks"
  like "$profile" "$home_re/.claude.json.lock" \
    "$editor profile includes the Claude config lock"
  like "$profile" '"/tmp/claude-[$]UID"' \
    "$editor profile includes Claude temporary state"
  like "$profile" "$home_re/.codex" \
    "$editor profile shares Codex credentials and state"
  like "$profile" "$home_re/.agents" \
    "$editor profile includes shared agent state"
  like "$profile" '"https://auth.openai.com"' \
    "$editor profile permits Codex login URLs"
  like "$profile" '"https://claude.ai"' \
    "$editor profile permits Claude login URLs"
  like "$profile" '"allow_localhost": true' \
    "$editor profile permits local OAuth callbacks"
  like "$profile" '"/etc/fonts"' \
    "$editor profile includes system font configuration"
  like "$profile" '"/var/cache/fontconfig"' \
    "$editor profile includes the system font cache"
  like "$profile" '"/dev/ptmx"' \
    "$editor profile can allocate pseudo-terminals"
  like "$profile" '"/etc/passwd"' \
    "$editor profile can resolve local users"
  like "$profile" '"/etc/shells"' \
    "$editor profile can discover terminal profiles"
  like "$profile" '"ipc_mode": "full"' \
    "$editor profile allows desktop IPC"
  like "$profile" '"access": "readwrite"' \
    "$editor profile grants its working directory read-write"
  like "$profile" '"/dev/shm"' \
    "$editor profile includes shared memory"
}

profile=$(cat "$ROOT/etc/cmd/code/profile.json")
like "$profile" "$home_re/.config/Code" \
  "code profile includes user data"
like "$profile" "$home_re/.vscode" \
  "code profile includes extensions"
like "$profile" "$home_re/.vscode-shared" \
  "code profile includes shared state"
check-agent-profile "$profile" code

profile=$(cat "$ROOT/etc/cmd/code-insiders/profile.json")
like "$profile" "$home_re/.config/Code - Insiders" \
  "code-insiders profile includes user data"
like "$profile" "$home_re/.vscode-insiders" \
  "code-insiders profile includes extensions"
like "$profile" "$home_re/.vscode-insiders-shared" \
  "code-insiders profile includes shared state"
check-agent-profile "$profile" code-insiders

# --show-config includes codex rg dependency
cache_test_project=$tmp/cache-test-project
mkdir -p "$cache_test_project"
git -C "$cache_test_project" init -q
cd "$cache_test_project" || exit
output=$("$pkio" --show-config codex)
ok $? "--show-config codex exits successfully"
like "$output" "rg.mk" \
  "--show-config codex includes rg makes dependency"
if test -d "$PKIO_CACHE/makes"; then rc=0; else rc=1; fi
ok $rc "--show-config uses the configured pkio cache for makes"
if test ! -e "$cache_test_project/.cache"; then rc=0; else rc=1; fi
ok $rc "--show-config does not create a project-local cache"
cd "$save_dir" || exit
unlike "$output" '\.config/gh' \
  "--show-config codex does not expose normal gh config"
printf '%s\n' "$output" > "$tmp/codex-config.mk"
output=$(PKIO_PROGRAM=codex PKIO_CONFIG_MK=$tmp/codex-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
ok $? "pkio-env codex exits successfully"
like "$output" 'projects\.".*"\.trust_level="trusted"' \
  "pkio-env codex trusts current project for this run"
like "$output" "--allow $PKIO_CACHE" \
  "pkio-env codex grants access to the configured pkio cache"
like "$output" "--allow $HOME/.codex" \
  "pkio-env codex grants access to global Codex instructions"
like "$output" "--read-file $HOME/.config/pkio/cache/claude/CLAUDE.md" \
  "pkio-env codex grants read access to global Claude instructions"
unlike "$output" "pkio-gh-readonly" \
  "pkio-env codex does not use read-only gh wrapper"
like "$output" "PKIO_GH_TOKEN_FILE=$PKIO_CONFIG/gh-token" \
  "pkio-env codex exports default gh token file"
mkdir -p "$HOME/.codex"
cat > "$HOME/.codex/config.toml" <<EOF
[projects."$save_dir"]
trust_level = "untrusted"
EOF
output=$(PKIO_PROGRAM=codex PKIO_CONFIG_MK=$tmp/codex-config.mk \
  PKIO_BASE=$save_dir make --no-print-directory -f "$ROOT/Makefile" \
  _codex-trust-project)
ok $? "codex project trust setup exits successfully"
like "$(cat "$HOME/.codex/config.toml")" 'trust_level = "trusted"' \
  "codex project trust setup persists trusted project"

# codex links a project AGENTS.md supplied from pkio config.
agents_project=$tmp/agents-project
agents_source=$HOME/.config/pkio${agents_project}/AGENTS.md
mkdir -p "$agents_project" "$(dirname "$agents_source")"
printf '%s\n' "configured agents instructions" > "$agents_source"
cd "$agents_project" || exit
output=$(PKIO_PROGRAM=codex PKIO_CONFIG_MK=$tmp/codex-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" _agents-md-link)
ok $? "codex AGENTS.md link setup exits successfully"
if test -L "$agents_project/AGENTS.md"; then rc=0; else rc=1; fi
ok $rc "codex links AGENTS.md from project config"
is "$(readlink "$agents_project/AGENTS.md")" "$agents_source" \
  "codex AGENTS.md link points to project config"
rm "$agents_project/AGENTS.md"
printf '%s\n' "existing agents instructions" > "$agents_project/AGENTS.md"
output=$(PKIO_PROGRAM=codex PKIO_CONFIG_MK=$tmp/codex-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" _agents-md-link)
ok $? "codex AGENTS.md setup preserves an existing file"
is "$(cat "$agents_project/AGENTS.md")" "existing agents instructions" \
  "codex does not replace an existing AGENTS.md"
cd "$save_dir" || exit

# claude uses nono wrap so nono does not inject its URL-opening helper.
output=$("$pkio" --show-config claude)
ok $? "--show-config claude exits successfully"
unlike "$output" '\.config/gh' \
  "--show-config claude does not expose normal gh config"
printf '%s\n' "$output" > "$tmp/claude-config.mk"
output=$(PKIO_PROGRAM=claude PKIO_CONFIG_MK=$tmp/claude-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
ok $? "pkio-env claude exits successfully"
like "$output" "PKIO_NONO_CMD='wrap'" \
  "pkio-env claude uses nono wrap"
like "$output" "--allow $PKIO_CACHE" \
  "pkio-env claude grants access to the configured pkio cache"
like "$output" "--allow $HOME/.config/pkio/cache/claude" \
  "pkio-env claude grants access to global Claude instructions"
like "$output" "--read-file $HOME/.codex/AGENTS.md" \
  "pkio-env claude grants read access to global Codex instructions"
like "$output" "--profile $ROOT/etc/cmd/claude/profile.json" \
  "pkio-env claude uses pkio claude profile"
unlike "$output" "pkio-gh-readonly" \
  "pkio-env claude does not use read-only gh wrapper"
like "$output" "PKIO_GH_TOKEN_FILE=$PKIO_CONFIG/gh-token" \
  "pkio-env claude exports default gh token file"

mkdir -p "$PKIO_CONFIG"
echo "test-token" > "$PKIO_CONFIG/gh-token"
output=$(bash -c '
  set -euo pipefail
  source "$1"
  config_home=$2
  program=codex
  setup-gh-env
  [[ ${GH_TOKEN-} == test-token ]]
  [[ ${PKIO_GH_TOKEN_FILE-} == "$2/gh-token" ]]
  [[ ${GH_PROMPT_DISABLED-} == 1 ]]
  [[ ${GH_NO_UPDATE_NOTIFIER-} == 1 ]]
  [[ ${GH_CONFIG_DIR-} == "/tmp/pkio-gh-$(id -u)" ]]
' bash "$pkio" "$PKIO_CONFIG" 2>&1)
ok $? "setup-gh-env exports read-only gh environment for codex"
is "$output" "" \
  "setup-gh-env test does not print gh token"
output=$(bash -c '
  set -euo pipefail
  source "$1"
  config_home=$2
  program=make
  setup-gh-env
  [[ -z ${GH_TOKEN-} ]]
  [[ -z ${PKIO_GH_TOKEN_FILE-} ]]
' bash "$pkio" "$PKIO_CONFIG" 2>&1)
ok $? "setup-gh-env ignores non-agent programs"
output=$(PKIO_PROGRAM=codex PKIO_CONFIG_MK=$tmp/codex-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
like "$output" "--read-file $PKIO_CONFIG/gh-token" \
  "pkio-env codex grants read-only access to gh token file"
unlike "$output" "test-token" \
  "pkio-env codex does not print gh token contents"
output=$(PKIO_PROGRAM=claude PKIO_CONFIG_MK=$tmp/claude-config.mk \
  make --no-print-directory -f "$ROOT/Makefile" pkio-env)
like "$output" "--read-file $PKIO_CONFIG/gh-token" \
  "pkio-env claude grants read-only access to gh token file"
unlike "$output" "test-token" \
  "pkio-env claude does not print gh token contents"

# claude browser defaults export browser opener wrappers
output=$("$pkio" --show-config claude)
ok $? "--show-config claude browser defaults exits successfully"
unlike "$output" 'BROWSER=' \
  "--show-config claude does not export BROWSER"
like "$output" 'PKIO-UNSET-ENV \+= BROWSER' \
  "--show-config claude unsets inherited BROWSER"
like "$output" 'PATH=\$\(PKIO-BROWSER-DIR\):\$\(PATH\)' \
  "--show-config claude prepends browser wrapper path"
like "$output" 'BROWSER-OPENERS := .*xdg-open.*sensible-browser.*open' \
  "--show-config claude creates common browser opener shims"
like "$output" '--allow-unix-socket-dir /tmp/\.X11-unix' \
  "--show-config claude allows X11 socket access"
like "$output" '--read-file /run/user/\$\(shell id -u\)/gdm/Xauthority' \
  "--show-config claude allows GDM Xauthority access"


# --stash / --link / --unlink cycle
project_dir=$tmp/project
mkdir -p "$project_dir"
git -C "$project_dir" init -q

echo "test content" > "$project_dir/myfile.txt"

cd "$project_dir" || exit

output=$("$pkio" --stash=myfile.txt 2>&1)
ok $? "--stash exits successfully"
like "$output" "Stashed:" \
  "--stash prints stash confirmation"

# File should now be a symlink
if test -L myfile.txt; then rc=0; else rc=1; fi
ok $rc "Stashed file is now a symlink"

# Original content preserved
content=$(cat myfile.txt)
is "$content" "test content" \
  "Symlinked file has original content"

# Stash dir should have the file
stash_dir=$PKIO_CONFIG/${project_dir#/}/stash
if test -f "$stash_dir/myfile.txt"; then rc=0; else rc=1; fi
ok $rc "File exists in stash directory"

# --unlink removes the symlink
output=$("$pkio" --unlink 2>&1)
ok $? "--unlink exits successfully"
like "$output" "Unlinked: myfile.txt" \
  "--unlink prints confirmation"
if test ! -e myfile.txt; then rc=0; else rc=1; fi
ok $rc "Symlink removed after --unlink"

# --link restores the symlink
output=$("$pkio" --link 2>&1)
ok $? "--link exits successfully"
like "$output" "Linked:" \
  "--link prints confirmation"
if test -L myfile.txt; then rc=0; else rc=1; fi
ok $rc "File is a symlink again after --link"
content=$(cat myfile.txt)
is "$content" "test content" \
  "Re-linked file has original content"


# --unlink with no stash
no_stash_dir=$tmp/no-stash
mkdir -p "$no_stash_dir"
git -C "$no_stash_dir" init -q

cd "$no_stash_dir" || exit
output=$("$pkio" --unlink 2>&1) || rc=$?
rc=${rc:-0}
isnt "$rc" 0 \
  "--unlink with no stash exits non-zero"
like "$output" "No pkio stash for:" \
  "--unlink with no stash shows friendly message"

# --link=<file> suggests --stash when file exists in cwd but not stashed
echo "hello" > "$no_stash_dir/CLAUDE.md"
output=$("$pkio" --link=CLAUDE.md 2>&1) || true
like "$output" "Did you mean: pkio --stash=CLAUDE.md" \
  "--link=<file> with no stash suggests --stash"


# --stash errors
cd "$project_dir" || exit

# Stash a nonexistent file
output=$("$pkio" --stash=nonexistent.txt 2>&1) || true
like "$output" "File not found" \
  "--stash nonexistent file shows error"

# Stash a symlink
output=$("$pkio" --stash=myfile.txt 2>&1) || true
like "$output" "already a symlink" \
  "--stash a symlink shows error"


# Unknown flag
output=$("$pkio" --bogus 2>&1) || true
like "$output" "Unknown flag" \
  "Unknown flag shows error"


# Running from HOME is rejected
cd "$HOME" || exit
output=$("$pkio" --show-config 2>&1) || true
like "$output" "Don't run pkio in your HOME" \
  "Running from HOME is rejected"


cd "$save_dir" || exit

done-testing
