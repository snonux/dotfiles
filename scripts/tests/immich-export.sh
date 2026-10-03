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
# Match several spellings so a trivial rename does not vacate the check.
# shellcheck disable=SC2016  # intentional literal $ patterns in grep
unsafe_join_re='account_dir/\$\{?filename'
if grep -E "$unsafe_join_re" "$IMMICH_EXPORT" | grep -v '_safe_export_filename' | grep -q .; then
    fail "raw filename still joined under account_dir"
fi
# shellcheck disable=SC2016
if grep -E '\$dest\.tmp|"\$\{dest\}\.tmp"|dest="\$\{?account_dir' "$IMMICH_EXPORT" \
    | grep -E '\.tmp|/\$\{?filename' | grep -q .; then
    # Explicit ban on curl -o "$dest.tmp" symlink write-through pattern.
    # shellcheck disable=SC2016
    if grep -Eq 'tmp="\$\{?dest\}\.tmp"|tmp="\$dest\.tmp"' "$IMMICH_EXPORT"; then
        fail "dest.tmp temp path still present (symlink write-through)"
    fi
fi
grep -q '_safe_export_filename' "$IMMICH_EXPORT" \
    || fail "missing _safe_export_filename helper"
grep -q '_path_is_under' "$IMMICH_EXPORT" \
    || fail "missing _path_is_under containment helper"
grep -q 'mktemp' "$IMMICH_EXPORT" \
    || fail "missing mktemp-based download temp"
grep -q 'destination collision' "$IMMICH_EXPORT" \
    || fail "missing same-run collision detection"
grep -q 'BASH_SOURCE' "$IMMICH_EXPORT" \
    || fail "main is not gated for sourcing in tests"
# Must not wipe real exports named *.tmp
if grep -E -- 'find .* -name ["'\'']\*\.tmp' "$IMMICH_EXPORT" | grep -q .; then
    fail "stale cleanup still uses find -name '*.tmp'"
fi

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

# --- Negative unit: absolute, empty, . / .., tab/newline ---
for bad in '' '/' '/tmp/pwned.jpg' '..' '.' 'foo/..' '../..' '/' \
    $'has\ttab.jpg' $'has\nnewline.jpg' $'has\rcarriage.jpg'; do
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

# --- Curl spy: log every -o / URL invocation ---
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/calls"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
url=""
args=("$@")
printf '%s\n' "${args[*]}" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -H|-d|-X|-m|-w) shift 2 ;;
        -sf|-s|-f|-L) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ -n "$out" ]] || exit 1
# Record dest path separately for assertions.
printf 'out=%s url=%s\n' "$out" "$url" >>"${log}.outs"
printf 'payload\n' >"$out"
EOF
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"
export CURL_SPY_LOG="$TEST_ROOT/calls/curl.log"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"

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
    || fail "download_assets failed on mixed list"

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

# Curl must not be invoked for refused rows (abs / ..).
if grep -E 'id-abs|id-dotdot|/tmp/pwned' "$CURL_SPY_LOG" "$CURL_SPY_LOG.outs" 2>/dev/null | grep -q .; then
    fail "curl spy saw refused asset rows: $(cat "$CURL_SPY_LOG" "$CURL_SPY_LOG.outs")"
fi
# Allowed downloads only.
grep -q 'id-trav\|id-ok\|/assets/id-trav/\|/assets/id-ok/' "$CURL_SPY_LOG" \
    || fail "curl spy missing expected download calls"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 2 ]] \
    || fail "expected exactly 2 curl -o writes, got $outs"

# Resolved dest for traversal must stay under ACCOUNT_DIR.
escape_real=$(cd "$(dirname "$ACCOUNT_DIR/escape.jpg")" && pwd -P)
account_real=$(cd "$ACCOUNT_DIR" && pwd -P)
[[ "$escape_real" == "$account_real" ]] \
    || fail "escape.jpg parent ${escape_real@Q} != account ${account_real@Q}"

# --- Symlink .tmp write-through: planted dest.tmp must not receive payload ---
rm -f "$ESCAPE_MARKER" "$ACCOUNT_DIR/planted.jpg" "$ACCOUNT_DIR/planted.jpg.tmp"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
# Classic attack: curl -o "$dest.tmp" follows a symlink outside account_dir.
ln -s "$ESCAPE_MARKER" "$ACCOUNT_DIR/planted.jpg.tmp"
printf '%s\n' $'id-plant\tplanted.jpg' >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-plant" 2>"$TEST_ROOT/err-plant" \
    || fail "download_assets failed on planted.tmp fixture"
[[ ! -e "$ESCAPE_MARKER" ]] \
    || fail "payload escaped via planted .tmp symlink to $ESCAPE_MARKER"
[[ -f "$ACCOUNT_DIR/planted.jpg" ]] \
    || fail "planted.jpg not written inside account_dir after mktemp download"
# Payload must not have followed the symlink (marker absent or empty).
if [[ -f "$ESCAPE_MARKER" ]]; then
    fail "escape marker file was created via symlink write-through"
fi
# mktemp path used — not the planted .tmp
if grep -Fq "out=$ACCOUNT_DIR/planted.jpg.tmp" "$CURL_SPY_LOG.outs"; then
    fail "curl wrote to planted.jpg.tmp instead of mktemp"
fi
grep -Eq "out=$ACCOUNT_DIR/\.immich-export\." "$CURL_SPY_LOG.outs" \
    || fail "curl -o was not an .immich-export.* mktemp path"

# --- Same-run collision after basename collapse (g33 residual) ---
rm -f "$ACCOUNT_DIR/same.jpg"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' \
    $'id-a\t../same.jpg' \
    $'id-b\tdir/same.jpg' \
    >"$ASSET_LIST"
set +e
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-coll" 2>"$TEST_ROOT/err-coll"
coll_rc=$?
set -e
[[ "$coll_rc" -ne 0 ]] \
    || fail "same-run basename collision should fail download_assets"
grep -q 'destination collision' "$TEST_ROOT/err-coll" \
    || fail "missing collision error: $(cat "$TEST_ROOT/err-coll")"
# First wins; second refused — not a silent skip-as-success.
[[ -f "$ACCOUNT_DIR/same.jpg" ]] \
    || fail "first colliding asset should still download"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 1 ]] \
    || fail "collision: expected 1 curl write, got $outs (silent double or none)"
grep -q 'id-b' "$CURL_SPY_LOG" \
    && fail "curl must not fetch colliding second asset id-b"

# --- Containment helper unit ---
_path_is_under "$ACCOUNT_DIR" "$ACCOUNT_DIR/normal.jpg" \
    || fail "_path_is_under rejected in-dir path"
if _path_is_under "$ACCOUNT_DIR" "$DEST_PARENT/escape.jpg" 2>/dev/null; then
    fail "_path_is_under accepted path outside account_dir"
fi

printf 'immich-export test: ok\n'
