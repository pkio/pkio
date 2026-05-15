#!/usr/bin/env bash

source test/init

pkio=$ROOT/bin/pkio

# Set up a temp directory for test isolation
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export PKIO_ROOT=$ROOT
export PKIO_CONFIG=$tmp/config
export PKIO_CACHE=$tmp/cache
unset NONO_CAP_FILE

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
