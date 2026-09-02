#!/usr/bin/env bash

source test/init

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

args_file=$tmp/args
fake_gdbus=$tmp/gdbus
portal_open=$ROOT/util/portal-open

cat > "$fake_gdbus" <<'EOF'
#!/usr/bin/env bash

printf '%s\0' "$@" >> "$PKIO_TEST_ARGS_FILE"
EOF
chmod +x "$fake_gdbus"

export PKIO_PORTAL_GDBUS=$fake_gdbus
export PKIO_TEST_ARGS_FILE=$args_file

"$portal_open" https://example.com
ok $? "portal opener accepts a URL"

mapfile -d '' -t args < "$args_file"
is "${args[0]}" call \
  "portal opener calls gdbus"
is "${args[1]}" --session \
  "portal opener uses the desktop session bus"
is "${args[3]}" org.freedesktop.portal.Desktop \
  "portal opener targets the desktop portal"
is "${args[7]}" org.freedesktop.portal.OpenURI.OpenURI \
  "portal opener calls OpenURI"
is "${args[9]}" https://example.com \
  "portal opener passes the URL"

gio=$tmp/gio
ln -s "$portal_open" "$gio"
: > "$args_file"
"$gio" open https://example.org
ok $? "gio-compatible invocation accepts open and a URL"
mapfile -d '' -t args < "$args_file"
is "${args[9]}" https://example.org \
  "gio-compatible invocation strips the open argument"

rc=0
output=$("$portal_open" --new-window 2>&1) || rc=$?
is "$rc" 1 \
  "portal opener rejects an invocation without a URL"
like "$output" "No URL was provided" \
  "portal opener explains the missing URL"

done-testing
