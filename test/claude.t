#!/usr/bin/env bash

source test/init
source "$ROOT/bin/pkio"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/main" "$tmp/makes" "$tmp/home"
touch "$tmp/makes/jq.mk"

# Inspect the real Claude rules without installing or authenticating Claude.
cat > "$tmp/Makefile" <<'MAKE'
PKIO-GH-READONLY-LOADED := true
include $(PKIO_ROOT)/makes/claude.mk

show-options:
	@echo '$(PKIO-NONO-OPTS)'
MAKE

export HOME=$tmp/home
export PKIO_ROOT=$ROOT
unset PKIO_CONFIG_MK

git -C "$tmp/main" init -q
git -C "$tmp/main" -c user.name=Test -c user.email=test@example.com \
  commit -qm Initial --allow-empty
git -C "$tmp/main" worktree add -qb nested "$tmp/main/worktree/topic"
git -C "$tmp/main" worktree add -qb external "$tmp/external"

options() (
  cd "$1" || exit
  base=$(get-project-base)
  make --no-print-directory -s -f "$tmp/Makefile" show-options \
    MAKES="$tmp/makes" PKIO_BASE="$base"
)

output=$(options "$tmp/main/worktree/topic")
unlike "$output" "--read $tmp/main/.claude" \
  "missing main checkout settings do not generate a grant"

mkdir "$tmp/main/.claude"
printf '{}\n' > "$tmp/main/.claude/settings.local.json"
for checkout in "$tmp/main" "$tmp/main/worktree/topic" "$tmp/external"; do
  output=$(options "$checkout")
  like "$output" "--read $tmp/main/.claude" \
    "Claude can read main checkout settings from $checkout"
  unlike "$output" "--allow $tmp/main" \
    "Claude rules do not grant write access to the main checkout"
done

done-testing
