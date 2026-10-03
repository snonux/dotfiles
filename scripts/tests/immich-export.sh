#!/usr/bin/env bash
# Path-safety checks for scripts/immich-export originalFileName handling (243).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r IMMICH_EXPORT="${SCRIPT_DIR}/../immich-export"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'immich-export test: %s\n' "$*" >&2
    exit 1
}

bash -n "$IMMICH_EXPORT" || fail "bash -n failed"
shellcheck -x "$IMMICH_EXPORT" || fail "shellcheck failed"

# Structural guards: never join raw API filename onto account_dir.
# shellcheck disable=SC2016
if grep -Fq 'dest="$account_dir/$filename"' "$IMMICH_EXPORT"; then
    fail "pre-fix dest=\$account_dir/\$filename join still present"
fi
grep -q '_safe_export_filename' "$IMMICH_EXPORT" \
    || fail "missing _safe_export_filename helper"
grep -q 'BASH_SOURCE' "$IMMICH_EXPORT" \
    || fail "main is not gated for sourcing in tests"

# Source helpers only (main is gated on BASH_SOURCE).
# shellcheck source=scripts/immich-export
source "$IMMICH_EXPORT"

# --- Unit: safe names pass through basename ---
got=$(_safe_export_filename 'IMG_1234.JPG') \
    || fail "plain filename rejected"
[[ "$got" == 'IMG_1234.JPG' ]] || fail "plain got=${got@Q}"

got=$(_safe_export_filename 'album/nested/photo.jpg') \
    || fail "nested relative rejected"
[[ "$got" == 'photo.jpg' ]] || fail "nested got=${got@Q}"

# Traversal-style names must collapse to a single component inside DEST.
got=$(_safe_export_filename '../escape.jpg') \
    || fail "../escape.jpg rejected after basename"
[[ "$got" == 'escape.jpg' ]] || fail "../escape got=${got@Q}"

got=$(_safe_export_filename 'foo/../../escape.jpg') \
    || fail "foo/../../escape.jpg rejected after basename"
[[ "$got" == 'escape.jpg' ]] || fail "multi-dotdot got=${got@Q}"

# --- Negative unit: absolute, empty, . / .. ---
for bad in '' '/' '/tmp/pwned.jpg' '..' '.' 'foo/..' '../..' '/'; do
    if _safe_export_filename "$bad" >/dev/null 2>&1; then
        fail "accepted unsafe originalFileName: ${bad@Q}"
    fi
done

# --- Repro: unsanitized join escapes account_dir ---
declare -r DEST_PARENT="$TEST_ROOT/dest"
declare -r ACCOUNT_DIR="$DEST_PARENT/paul"
mkdir -p "$ACCOUNT_DIR"
declare -r ESCAPE_MARKER="$DEST_PARENT/escape.jpg"
rm -f "$ESCAPE_MARKER"

filename='../escape.jpg'
buggy_dest="$ACCOUNT_DIR/$filename"
# Touch via the old join form — proves the escape path exists.
: >"$buggy_dest"
[[ -f "$ESCAPE_MARKER" ]] \
    || fail "buggy join repro did not write outside account_dir"
rm -f "$ESCAPE_MARKER"

# --- Integration: download_assets must not escape account_dir ---
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/calls"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Minimal Immich original download stub: write payload to -o path.
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -H|-d|-X|-m|-w) shift 2 ;;
        -sf|-s|-f|-L) shift ;;
        *) shift ;;
    esac
done
[[ -n "$out" ]] || exit 1
printf 'payload\n' >"$out"
EOF
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"

declare -r ASSET_LIST="$TEST_ROOT/assets.tsv"
# Mix: traversal, absolute (must refuse), and a normal name.
printf '%s\n' \
    $'id-trav\t../escape.jpg' \
    $'id-abs\t/tmp/pwned.jpg' \
    $'id-dotdot\t..' \
    $'id-ok\tnormal.jpg' \
    >"$ASSET_LIST"

rm -f "$ESCAPE_MARKER" "$ACCOUNT_DIR/escape.jpg" "$ACCOUNT_DIR/normal.jpg"
rm -rf "$ACCOUNT_DIR/tmp"

download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" \
    || fail "download_assets failed"

[[ ! -e "$ESCAPE_MARKER" ]] \
    || fail "path traversal wrote outside account_dir: $ESCAPE_MARKER"
[[ -f "$ACCOUNT_DIR/escape.jpg" ]] \
    || fail "basename traversal name not written inside account_dir"
[[ -f "$ACCOUNT_DIR/normal.jpg" ]] \
    || fail "normal.jpg not downloaded"
# Absolute names must be refused (never joined; naive join would create
# account_dir/tmp/pwned.jpg because bash string concat keeps the prefix).
[[ ! -e "$ACCOUNT_DIR/tmp/pwned.jpg" ]] \
    || fail "absolute originalFileName was joined under account_dir"
[[ ! -e "$ACCOUNT_DIR/pwned.jpg" ]] \
    || fail "absolute-path asset was written under account_dir"

grep -q 'refusing unsafe originalFileName' "$TEST_ROOT/err" \
    || fail "expected refuse message for unsafe names missing"
grep -Fq "refusing unsafe originalFileName: '/tmp/pwned.jpg'" "$TEST_ROOT/err" \
    || fail "absolute path was not refused: $(cat "$TEST_ROOT/err")"
grep -Fq "refusing unsafe originalFileName: '..'" "$TEST_ROOT/err" \
    || fail "'..' was not refused: $(cat "$TEST_ROOT/err")"

# Resolved dest for traversal must stay under ACCOUNT_DIR.
escape_real=$(cd "$(dirname "$ACCOUNT_DIR/escape.jpg")" && pwd -P)
account_real=$(cd "$ACCOUNT_DIR" && pwd -P)
[[ "$escape_real" == "$account_real" ]] \
    || fail "escape.jpg parent ${escape_real@Q} != account ${account_real@Q}"

printf 'immich-export test: ok\n'
