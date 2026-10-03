#!/usr/bin/env bash
# Path-safety, unique-naming (243, g33), and resilience (q33) checks for
# scripts/immich-export.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r IMMICH_EXPORT="${SCRIPT_DIR}/../immich-export"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

# Stable UUID fixtures (Immich asset ids are UUIDs; '_' join is injective).
declare -r ID_TRAV='11111111-1111-1111-1111-111111111111'
declare -r ID_ABS='22222222-2222-2222-2222-222222222222'
declare -r ID_DOTDOT='33333333-3333-3333-3333-333333333333'
declare -r ID_OK='44444444-4444-4444-4444-444444444444'
declare -r ID_PLANT='55555555-5555-5555-5555-555555555555'
declare -r ID_A='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
declare -r ID_B='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
declare -r ID_C='cccccccc-cccc-cccc-cccc-cccccccccccc'
declare -r ID_DUP='dddddddd-dddd-dddd-dddd-dddddddddddd'
declare -r ID_FAIL='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'

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
grep -q '_safe_asset_id' "$IMMICH_EXPORT" \
    || fail "missing _safe_asset_id helper"
grep -q '_unique_export_basename' "$IMMICH_EXPORT" \
    || fail "missing _unique_export_basename helper"
grep -q '_path_is_under' "$IMMICH_EXPORT" \
    || fail "missing _path_is_under containment helper"
grep -q 'mktemp' "$IMMICH_EXPORT" \
    || fail "missing mktemp-based download temp"
grep -q 'duplicate asset id' "$IMMICH_EXPORT" \
    || fail "missing duplicate asset id detection"
grep -q 'destination collision' "$IMMICH_EXPORT" \
    || fail "missing same-run destination collision detection"
grep -q 'BASH_SOURCE' "$IMMICH_EXPORT" \
    || fail "main is not gated for sourcing in tests"
# q33 resilience: URL failover, timeouts, fail count, CLI/env knobs.
grep -q 'detect_immich_url' "$IMMICH_EXPORT" \
    || fail "missing detect_immich_url helper"
grep -q 'immich_reachable' "$IMMICH_EXPORT" \
    || fail "missing immich_reachable helper"
grep -q 'IMMICH_LAN_URL' "$IMMICH_EXPORT" \
    || fail "missing IMMICH_LAN_URL"
grep -q 'IMMICH_PUBLIC_URL' "$IMMICH_EXPORT" \
    || fail "missing IMMICH_PUBLIC_URL"
grep -q 'CURL_PING_TIMEOUT' "$IMMICH_EXPORT" \
    || fail "missing CURL_PING_TIMEOUT"
grep -q 'CURL_SEARCH_TIMEOUT' "$IMMICH_EXPORT" \
    || fail "missing CURL_SEARCH_TIMEOUT"
grep -q 'CURL_DOWNLOAD_TIMEOUT' "$IMMICH_EXPORT" \
    || fail "missing CURL_DOWNLOAD_TIMEOUT"
# shellcheck disable=SC2016  # intentional literal $CURL_* in grep
grep -Eq 'curl .* -m "\$CURL_DOWNLOAD_TIMEOUT"|curl -sf -m "\$CURL_DOWNLOAD_TIMEOUT"' \
    "$IMMICH_EXPORT" \
    || fail "download curl missing -m CURL_DOWNLOAD_TIMEOUT"
# shellcheck disable=SC2016
grep -Eq 'curl .* -m "\$CURL_SEARCH_TIMEOUT"|curl -sf -m "\$CURL_SEARCH_TIMEOUT"' \
    "$IMMICH_EXPORT" \
    || fail "search curl missing -m CURL_SEARCH_TIMEOUT"
grep -q 'failed (download errors)' "$IMMICH_EXPORT" \
    || fail "Done summary missing failed download count"
grep -q 'failed == 0 && collided == 0' "$IMMICH_EXPORT" \
    || fail "download_assets must fail when failed or collided"
grep -q 'IMMICH_EXPORT_DEST' "$IMMICH_EXPORT" \
    || fail "missing IMMICH_EXPORT_DEST env support"
grep -q 'IMMICH_EXPORT_AFTER' "$IMMICH_EXPORT" \
    || fail "missing IMMICH_EXPORT_AFTER env support"
grep -q 'IMMICH_EXPORT_BEFORE' "$IMMICH_EXPORT" \
    || fail "missing IMMICH_EXPORT_BEFORE env support"
grep -q -- '--dest' "$IMMICH_EXPORT" \
    || fail "missing --dest CLI flag"
grep -q -- '--account' "$IMMICH_EXPORT" \
    || fail "missing --account CLI flag"
grep -q '_safe_account_name' "$IMMICH_EXPORT" \
    || fail "missing _safe_account_name allowlist helper"
# shellcheck disable=SC2016
grep -Eq '\[\^A-Za-z0-9_-\]\+|\[A-Za-z0-9_-\]\+' "$IMMICH_EXPORT" \
    || fail "missing account name allowlist character class"
# Must not wipe real exports named *.tmp
if grep -E -- 'find .* -name ["'\'']\*\.tmp' "$IMMICH_EXPORT" | grep -q .; then
    fail "stale cleanup still uses find -name '*.tmp'"
fi
# Dest must use uniquified name, not sanitized basename alone.
# shellcheck disable=SC2016
if grep -Eq 'dest="\$\{?account_dir\}/\$\{?safe\}"' "$IMMICH_EXPORT"; then
    fail "dest still joins sanitized basename without asset-id uniquify"
fi
# UUID allowlist must be present (injective '_' join).
grep -Eq '\[0-9a-fA-F\]\{8\}' "$IMMICH_EXPORT" \
    || fail "missing UUID allowlist in _safe_asset_id"
# Done summary must not claim every refuse is only 'unsafe name'.
if grep -Fq 'refused (unsafe name)' "$IMMICH_EXPORT"; then
    fail "Done summary still labels all refuses as unsafe name only"
fi
# Must not hardcode a single LAN-only IMMICH_URL without failover.
if grep -Eq '^IMMICH_URL="http://immich\.f3s\.lan' "$IMMICH_EXPORT"; then
    fail "IMMICH_URL still hardcoded to LAN-only (no failover)"
fi

# Source helpers only (main is gated on BASH_SOURCE).
# shellcheck source=scripts/immich-export
source "$IMMICH_EXPORT"

# download_assets builds URLs from IMMICH_URL (set by detect_immich_url in main).
IMMICH_URL='http://immich.test.example'

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

# --- Negative unit: absolute, empty, . / .., tab/newline/CR ---
for bad in '' '/' '/tmp/pwned.jpg' '..' '.' 'foo/..' '../..' '/' \
    $'has\ttab.jpg' $'has\nnewline.jpg' $'has\rcarriage.jpg'; do
    if _safe_export_filename "$bad" >/dev/null 2>&1; then
        fail "accepted unsafe originalFileName: ${bad@Q}"
    fi
done

# --- Unit: unique basename prefixes UUID asset id ---
got=$(_unique_export_basename "$ID_A" 'same.jpg') \
    || fail "unique basename rejected for ID_A/same.jpg"
[[ "$got" == "${ID_A}_same.jpg" ]] || fail "unique got=${got@Q}"

# Injective: UUID has no '_', so id is always the parseable prefix.
got=$(_unique_export_basename "$ID_A" 'c_d.jpg') \
    || fail "unique basename rejected for underscore basename"
[[ "$got" == "${ID_A}_c_d.jpg" ]] || fail "underscore basename got=${got@Q}"
got2=$(_unique_export_basename "$ID_B" 'd.jpg') \
    || fail "unique basename rejected for ID_B/d.jpg"
[[ "$got" != "$got2" ]] || fail "distinct UUID pairs must not share dest name"

# --- Negative: old '_' join ambiguity (non-UUID ids that collide) ---
# ab + c_d.jpg and ab_c + d.jpg both became ab_c_d.jpg under naive join.
# UUID allowlist refuses both non-UUID ids so that ambiguity cannot arise.
for ambiguous_id in 'ab' 'ab_c'; do
    if _safe_asset_id "$ambiguous_id" >/dev/null 2>&1; then
        fail "accepted non-UUID id that participates in '_' join ambiguity: ${ambiguous_id@Q}"
    fi
    if _unique_export_basename "$ambiguous_id" 'c_d.jpg' >/dev/null 2>&1; then
        fail "unique basename accepted ambiguous non-UUID id: ${ambiguous_id@Q}"
    fi
    if _unique_export_basename "$ambiguous_id" 'd.jpg' >/dev/null 2>&1; then
        fail "unique basename accepted ambiguous non-UUID id: ${ambiguous_id@Q}"
    fi
done

# --- Negative unit: unsafe / non-UUID asset ids (incl. CR) ---
for bad_id in '' '/' '/tmp/x' '..' '.' $'has\tid' $'has\nid' $'has\rid' \
    'a/b' 'id-a' 'not-a-uuid' \
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa' \
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaaa' \
    'gggggggg-gggg-gggg-gggg-gggggggggggg'; do
    if _safe_asset_id "$bad_id" >/dev/null 2>&1; then
        fail "accepted unsafe asset id: ${bad_id@Q}"
    fi
    if _unique_export_basename "$bad_id" 'ok.jpg' >/dev/null 2>&1; then
        fail "unique basename accepted unsafe asset id: ${bad_id@Q}"
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

# --- Curl spy: log every -o / URL invocation; require -m timeout ---
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/calls"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
url=""
has_m=0
args=("$@")
printf '%s\n' "${args[*]}" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) has_m=1; shift 2 ;;
        -H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
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
    "${ID_TRAV}"$'\t../escape.jpg' \
    "${ID_ABS}"$'\t/tmp/pwned.jpg' \
    "${ID_DOTDOT}"$'\t..' \
    "${ID_OK}"$'\tnormal.jpg' \
    >"$ASSET_LIST"

rm -f "$ESCAPE_MARKER" \
    "$ACCOUNT_DIR/${ID_TRAV}_escape.jpg" \
    "$ACCOUNT_DIR/${ID_OK}_normal.jpg" \
    "$ACCOUNT_DIR/escape.jpg" \
    "$ACCOUNT_DIR/normal.jpg"
rm -rf "$ACCOUNT_DIR/tmp"

download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" \
    || fail "download_assets failed on mixed list"

[[ ! -e "$ESCAPE_MARKER" ]] \
    || fail "path traversal wrote outside account_dir: $ESCAPE_MARKER"
[[ -f "$ACCOUNT_DIR/${ID_TRAV}_escape.jpg" ]] \
    || fail "basename traversal name not written as unique dest inside account_dir"
[[ -f "$ACCOUNT_DIR/${ID_OK}_normal.jpg" ]] \
    || fail "${ID_OK}_normal.jpg not downloaded"
# Absolute names must be refused (never joined; naive join would create
# account_dir/tmp/pwned.jpg because bash string concat keeps the prefix).
[[ ! -e "$ACCOUNT_DIR/tmp/pwned.jpg" ]] \
    || fail "absolute originalFileName was joined under account_dir"
[[ ! -e "$ACCOUNT_DIR/pwned.jpg" ]] \
    || fail "absolute-path asset was written under account_dir"
[[ ! -e "$ACCOUNT_DIR/${ID_ABS}_pwned.jpg" ]] \
    || fail "absolute-path asset was uniquified/written under account_dir"

grep -q 'refusing unsafe originalFileName' "$TEST_ROOT/err" \
    || fail "expected refuse message for unsafe names missing"
grep -Fq "refusing unsafe originalFileName: '/tmp/pwned.jpg'" "$TEST_ROOT/err" \
    || fail "absolute path was not refused: $(cat "$TEST_ROOT/err")"
grep -Fq "refusing unsafe originalFileName: '..'" "$TEST_ROOT/err" \
    || fail "'..' was not refused: $(cat "$TEST_ROOT/err")"

# Curl must not be invoked for refused rows (abs / ..).
if grep -E "${ID_ABS}|${ID_DOTDOT}|/tmp/pwned" "$CURL_SPY_LOG" "$CURL_SPY_LOG.outs" 2>/dev/null | grep -q .; then
    fail "curl spy saw refused asset rows: $(cat "$CURL_SPY_LOG" "$CURL_SPY_LOG.outs")"
fi
# Allowed downloads only.
grep -q "${ID_TRAV}\|${ID_OK}\|/assets/${ID_TRAV}/\|/assets/${ID_OK}/" "$CURL_SPY_LOG" \
    || fail "curl spy missing expected download calls"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 2 ]] \
    || fail "expected exactly 2 curl -o writes, got $outs"

# Resolved dest for traversal must stay under ACCOUNT_DIR.
escape_real=$(cd "$(dirname "$ACCOUNT_DIR/${ID_TRAV}_escape.jpg")" && pwd -P)
account_real=$(cd "$ACCOUNT_DIR" && pwd -P)
[[ "$escape_real" == "$account_real" ]] \
    || fail "escape.jpg parent ${escape_real@Q} != account ${account_real@Q}"

# --- Symlink .tmp write-through: planted dest.tmp must not receive payload ---
rm -f "$ESCAPE_MARKER" \
    "$ACCOUNT_DIR/${ID_PLANT}_planted.jpg" \
    "$ACCOUNT_DIR/planted.jpg" \
    "$ACCOUNT_DIR/planted.jpg.tmp"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
# Classic attack: curl -o "$dest.tmp" follows a symlink outside account_dir.
ln -s "$ESCAPE_MARKER" "$ACCOUNT_DIR/planted.jpg.tmp"
printf '%s\n' "${ID_PLANT}"$'\tplanted.jpg' >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-plant" 2>"$TEST_ROOT/err-plant" \
    || fail "download_assets failed on planted.tmp fixture"
[[ ! -e "$ESCAPE_MARKER" ]] \
    || fail "payload escaped via planted .tmp symlink to $ESCAPE_MARKER"
[[ -f "$ACCOUNT_DIR/${ID_PLANT}_planted.jpg" ]] \
    || fail "${ID_PLANT}_planted.jpg not written inside account_dir after mktemp download"
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

# --- g33: distinct IDs sharing sanitized basename both export ---
rm -f "$ACCOUNT_DIR/same.jpg" \
    "$ACCOUNT_DIR/${ID_A}_same.jpg" \
    "$ACCOUNT_DIR/${ID_B}_same.jpg"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' \
    "${ID_A}"$'\t../same.jpg' \
    "${ID_B}"$'\tdir/same.jpg' \
    >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-coll" 2>"$TEST_ROOT/err-coll" \
    || fail "same-basename distinct IDs should succeed: $(cat "$TEST_ROOT/err-coll")"
[[ -f "$ACCOUNT_DIR/${ID_A}_same.jpg" ]] \
    || fail "first colliding basename asset missing: ${ID_A}_same.jpg"
[[ -f "$ACCOUNT_DIR/${ID_B}_same.jpg" ]] \
    || fail "second colliding basename asset missing: ${ID_B}_same.jpg"
# Must not leave a bare basename-only dest (old incomplete-export scheme).
[[ ! -e "$ACCOUNT_DIR/same.jpg" ]] \
    || fail "bare same.jpg should not be written under unique-naming scheme"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 2 ]] \
    || fail "same-basename distinct IDs: expected 2 curl writes, got $outs"
grep -q "$ID_A" "$CURL_SPY_LOG" || fail "curl missing ID_A"
grep -q "$ID_B" "$CURL_SPY_LOG" || fail "curl missing ID_B"
grep -q 'destination collision\|duplicate asset id' "$TEST_ROOT/err-coll" \
    && fail "distinct IDs must not report collision/duplicate"

# --- g33: same unique dest already on disk skips only that asset ---
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' \
    "${ID_A}"$'\t../same.jpg' \
    "${ID_C}"$'\tsame.jpg' \
    >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-skip" 2>"$TEST_ROOT/err-skip" \
    || fail "exists-skip run should succeed: $(cat "$TEST_ROOT/err-skip")"
grep -q "skip (exists): ${ID_A}_same.jpg" "$TEST_ROOT/out-skip" \
    || fail "expected skip for existing ${ID_A}_same.jpg: $(cat "$TEST_ROOT/out-skip")"
[[ -f "$ACCOUNT_DIR/${ID_C}_same.jpg" ]] \
    || fail "${ID_C}_same.jpg should download despite ${ID_A}_same.jpg existing"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 1 ]] \
    || fail "exists-skip: expected 1 curl write (ID_C only), got $outs"

# --- g33 negative: duplicate asset id refused even with different basenames ---
rm -f "$ACCOUNT_DIR/${ID_DUP}_x.jpg" "$ACCOUNT_DIR/${ID_DUP}_y.jpg"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' \
    "${ID_DUP}"$'\tx.jpg' \
    "${ID_DUP}"$'\ty.jpg' \
    >"$ASSET_LIST"
set +e
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-dup" 2>"$TEST_ROOT/err-dup"
dup_rc=$?
set -e
[[ "$dup_rc" -ne 0 ]] \
    || fail "duplicate asset id should fail download_assets"
grep -q 'duplicate asset id' "$TEST_ROOT/err-dup" \
    || fail "missing duplicate asset id error: $(cat "$TEST_ROOT/err-dup")"
[[ -f "$ACCOUNT_DIR/${ID_DUP}_x.jpg" ]] \
    || fail "first duplicate-id row should still download"
[[ ! -e "$ACCOUNT_DIR/${ID_DUP}_y.jpg" ]] \
    || fail "second duplicate-id row must not write a different basename dest"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 1 ]] \
    || fail "duplicate asset id: expected 1 curl write, got $outs"
grep -q 'unsafe/invalid input\|duplicate id/dest' "$TEST_ROOT/out-dup" \
    || fail "Done summary missing broader refuse/collision labels: $(cat "$TEST_ROOT/out-dup")"

# --- g33 negative: duplicate asset id + same basename also refused by id ---
rm -f "$ACCOUNT_DIR/${ID_DUP}_x.jpg"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' \
    "${ID_DUP}"$'\tx.jpg' \
    "${ID_DUP}"$'\tdir/x.jpg' \
    >"$ASSET_LIST"
set +e
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-dup2" 2>"$TEST_ROOT/err-dup2"
dup2_rc=$?
set -e
[[ "$dup2_rc" -ne 0 ]] \
    || fail "duplicate asset id + same basename should fail"
grep -q 'duplicate asset id' "$TEST_ROOT/err-dup2" \
    || fail "same-basename dup id should report duplicate asset id: $(cat "$TEST_ROOT/err-dup2")"

# --- Negative: unsafe asset id refused (no curl, no write) ---
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' $'../evil\tok.jpg' >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-badid" 2>"$TEST_ROOT/err-badid" \
    || fail "unsafe asset id list should still return 0 (no collision)"
grep -q 'refusing unsafe asset id' "$TEST_ROOT/err-badid" \
    || fail "missing unsafe asset id refuse: $(cat "$TEST_ROOT/err-badid")"
[[ ! -e "$ACCOUNT_DIR/evil_ok.jpg" ]] \
    || fail "unsafe asset id wrote evil_ok.jpg"
[[ ! -e "$DEST_PARENT/evil_ok.jpg" ]] \
    || fail "unsafe asset id escaped via ../evil prefix"
outs=$(wc -l <"$CURL_SPY_LOG.outs")
[[ "$outs" -eq 0 ]] \
    || fail "unsafe asset id must not invoke curl -o"

# Non-UUID id that looks like old unique-naming prefix must also be refused.
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
printf '%s\n' $'id-a\tok.jpg' >"$ASSET_LIST"
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-nonuuid" 2>"$TEST_ROOT/err-nonuuid" \
    || fail "non-UUID asset id list should return 0"
grep -q 'refusing unsafe asset id' "$TEST_ROOT/err-nonuuid" \
    || fail "non-UUID id-a was not refused: $(cat "$TEST_ROOT/err-nonuuid")"
[[ ! -e "$ACCOUNT_DIR/id-a_ok.jpg" ]] \
    || fail "non-UUID id wrote id-a_ok.jpg"

# --- Containment helper unit ---
_path_is_under "$ACCOUNT_DIR" "$ACCOUNT_DIR/${ID_OK}_normal.jpg" \
    || fail "_path_is_under rejected in-dir path"
if _path_is_under "$ACCOUNT_DIR" "$DEST_PARENT/escape.jpg" 2>/dev/null; then
    fail "_path_is_under accepted path outside account_dir"
fi

# --- q33: download curl failure must exit non-zero and count failed ---
rm -f "$ACCOUNT_DIR/${ID_FAIL}_failme.jpg"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
has_m=0
args=("$@")
printf '%s\n' "${args[*]}" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) has_m=1; shift 2 ;;
        -H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
[[ -n "$out" ]] || exit 1
printf 'out=%s\n' "$out" >>"${log}.outs"
# Simulate network / HTTP failure (curl -sf non-zero).
exit 22
EOF
chmod +x "$TEST_ROOT/bin/curl"
printf '%s\n' "${ID_FAIL}"$'\tfailme.jpg' >"$ASSET_LIST"
set +e
download_assets 'fake-key' "$ACCOUNT_DIR" "$ASSET_LIST" \
    >"$TEST_ROOT/out-fail" 2>"$TEST_ROOT/err-fail"
fail_rc=$?
set -e
[[ "$fail_rc" -ne 0 ]] \
    || fail "download failure should make download_assets exit non-zero"
grep -q 'failed to download' "$TEST_ROOT/err-fail" \
    || fail "missing download failure message: $(cat "$TEST_ROOT/err-fail")"
grep -q '1 failed (download errors)' "$TEST_ROOT/out-fail" \
    || fail "Done summary missing failed count: $(cat "$TEST_ROOT/out-fail")"
[[ ! -e "$ACCOUNT_DIR/${ID_FAIL}_failme.jpg" ]] \
    || fail "failed download must not leave destination file"
# Temp must be cleaned up (no leftover .immich-export.*).
leftover=$(find "$ACCOUNT_DIR" -maxdepth 1 -type f -name '.immich-export.*' | wc -l)
[[ "$leftover" -eq 0 ]] \
    || fail "failed download left mktemp files behind"

# Restore successful download spy for any later checks.
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
url=""
has_m=0
args=("$@")
printf '%s\n' "${args[*]}" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) has_m=1; shift 2 ;;
        -H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
[[ -n "$out" ]] || exit 1
printf 'out=%s url=%s\n' "$out" "$url" >>"${log}.outs"
printf 'payload\n' >"$out"
EOF
chmod +x "$TEST_ROOT/bin/curl"

# --- q33: URL failover — LAN fail → public success ---
: >"$CURL_SPY_LOG"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
printf '%s\n' "$*" >>"$log"
url=""
has_m=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) has_m=1; shift 2 ;;
        -o|-H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
case "$url" in
    *lan.example*/api/server/ping)
        # LAN unreachable
        printf '000'
        exit 7
        ;;
    *public.example*/api/server/ping)
        printf '200'
        exit 0
        ;;
    *)
        echo "unexpected ping url: $url" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
IMMICH_LAN_URL='http://immich.lan.example'
IMMICH_PUBLIC_URL='https://immich.public.example'
IMMICH_URL=''
detect_immich_url >"$TEST_ROOT/out-detect" 2>"$TEST_ROOT/err-detect"
[[ "$IMMICH_URL" == "$IMMICH_PUBLIC_URL" ]] \
    || fail "expected public failover URL, got ${IMMICH_URL@Q}"
grep -q 'public ingress' "$TEST_ROOT/out-detect" \
    || fail "missing public failover message: $(cat "$TEST_ROOT/out-detect")"
grep -q 'lan.example' "$CURL_SPY_LOG" \
    || fail "LAN ping was not attempted"
grep -q 'public.example' "$CURL_SPY_LOG" \
    || fail "public ping was not attempted"

# --- q33 negative: both URLs unreachable → die ---
: >"$CURL_SPY_LOG"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CURL_SPY_LOG"
# Always fail ping.
printf '000'
exit 7
EOF
chmod +x "$TEST_ROOT/bin/curl"
IMMICH_URL=''
set +e
detect_out=$(detect_immich_url 2>&1)
detect_rc=$?
set -e
[[ "$detect_rc" -ne 0 ]] \
    || fail "detect_immich_url should die when both URLs are down"
[[ "$detect_out" == *'not reachable'* ]] \
    || fail "expected not-reachable die message: ${detect_out@Q}"

# --- q33: LAN reachable prefers LAN ---
: >"$CURL_SPY_LOG"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CURL_SPY_LOG"
url=""
has_m=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) has_m=1; shift 2 ;;
        -o|-H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || exit 2
case "$url" in
    *lan.example*/api/server/ping) printf '200'; exit 0 ;;
    *) printf '000'; exit 7 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
IMMICH_LAN_URL='http://immich.lan.example'
IMMICH_PUBLIC_URL='https://immich.public.example'
IMMICH_URL=''
detect_immich_url >"$TEST_ROOT/out-lan" 2>/dev/null
[[ "$IMMICH_URL" == "$IMMICH_LAN_URL" ]] \
    || fail "expected LAN URL when reachable, got ${IMMICH_URL@Q}"
if grep -q 'public.example' "$CURL_SPY_LOG"; then
    fail "public ping should not run when LAN succeeds"
fi

# --- q33: env defaults for DEST/dates are honored when sourced ---
# Re-source in a subshell with env overrides to avoid clobbering test state.
env_out=$(
    IMMICH_EXPORT_DEST="$TEST_ROOT/env-dest" \
    IMMICH_EXPORT_AFTER='2020-01-01T00:00:00.000Z' \
    IMMICH_EXPORT_BEFORE='2020-02-01T00:00:00.000Z' \
    bash -c '
        set -euo pipefail
        # shellcheck source=scripts/immich-export
        source "$1"
        printf "%s\n" "$DEST_DIR"
        printf "%s\n" "$DATE_AFTER"
        printf "%s\n" "$DATE_BEFORE"
    ' bash "$IMMICH_EXPORT"
) || fail "env-default subshell failed"
mapfile -t env_lines <<<"$env_out"
[[ "${env_lines[0]}" == "$TEST_ROOT/env-dest" ]] \
    || fail "IMMICH_EXPORT_DEST not applied: ${env_lines[0]@Q}"
[[ "${env_lines[1]}" == '2020-01-01T00:00:00.000Z' ]] \
    || fail "IMMICH_EXPORT_AFTER not applied: ${env_lines[1]@Q}"
[[ "${env_lines[2]}" == '2020-02-01T00:00:00.000Z' ]] \
    || fail "IMMICH_EXPORT_BEFORE not applied: ${env_lines[2]@Q}"

# --- q33 negative: unknown CLI option exits non-zero ---
set +e
"$IMMICH_EXPORT" --not-a-real-flag >/dev/null 2>"$TEST_ROOT/err-cli"
cli_rc=$?
set -e
[[ "$cli_rc" -ne 0 ]] \
    || fail "unknown CLI flag should fail"
grep -qi 'unknown option' "$TEST_ROOT/err-cli" \
    || fail "missing unknown-option message: $(cat "$TEST_ROOT/err-cli")"

# --- q33: --help exits 0 ---
"$IMMICH_EXPORT" --help >"$TEST_ROOT/out-help" 2>"$TEST_ROOT/err-help" \
    || fail "--help should exit 0"
grep -q -- '--dest' "$TEST_ROOT/out-help" \
    || fail "--help missing --dest"
grep -q -- '--account' "$TEST_ROOT/out-help" \
    || fail "--help missing --account"

# --- q33 P0: account allowlist unit ---
got=$(_safe_account_name 'paul') || fail "plain account rejected"
[[ "$got" == 'paul' ]] || fail "plain account got=${got@Q}"
got=$(_safe_account_name 'albena_2') || fail "underscore account rejected"
[[ "$got" == 'albena_2' ]] || fail "underscore account got=${got@Q}"
got=$(_safe_account_name 'A-Z9') || fail "alnum-hyphen account rejected"
[[ "$got" == 'A-Z9' ]] || fail "alnum-hyphen got=${got@Q}"
for bad_acct in '' '.' '..' '../elsewhere' 'foo/bar' '/abs' \
    'has space' $'has\ttab' 'evil;rm' 'a.b' '~paul'; do
    if _safe_account_name "$bad_acct" >/dev/null 2>&1; then
        fail "accepted unsafe account name: ${bad_acct@Q}"
    fi
done

# --- q33 P0: --account path escape rejected before DEST/key use ---
set +e
"$IMMICH_EXPORT" --account '../elsewhere' --dest "$TEST_ROOT/acct-escape" \
    >/dev/null 2>"$TEST_ROOT/err-acct-escape"
acct_esc_rc=$?
set -e
[[ "$acct_esc_rc" -ne 0 ]] \
    || fail "--account ../elsewhere should be rejected"
grep -qi 'invalid account' "$TEST_ROOT/err-acct-escape" \
    || fail "missing invalid-account message: $(cat "$TEST_ROOT/err-acct-escape")"
[[ ! -e "$TEST_ROOT/elsewhere" ]] \
    || fail "--account ../elsewhere created escape path"
[[ ! -d "$TEST_ROOT/acct-escape/../elsewhere" ]] \
    || fail "--account ../elsewhere created DEST escape dir"

# --- q33 P1: missing flag arguments die ---
for flag in --dest --after --before --account --lan-url --public-url; do
    set +e
    "$IMMICH_EXPORT" "$flag" >/dev/null 2>"$TEST_ROOT/err-missing-arg"
    miss_rc=$?
    set -e
    [[ "$miss_rc" -ne 0 ]] \
        || fail "$flag without argument should die"
    grep -Eqi 'requires|argument' "$TEST_ROOT/err-missing-arg" \
        || fail "$flag missing-arg message wrong: $(cat "$TEST_ROOT/err-missing-arg")"
done

# --- q33 P2: discover_assets curl spy requires -m (and search timeout) ---
: >"$CURL_SPY_LOG"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
has_m=0
m_val=""
printf '%s\n' "$*" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) has_m=1; m_val="$2"; shift 2 ;;
        -o|-H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
printf 'm=%s\n' "$m_val" >>"${log}.mvals"
# One page of search results, no nextPage.
cat <<'JSON'
{"assets":{"items":[{"id":"44444444-4444-4444-4444-444444444444","originalFileName":"disc.jpg"}],"nextPage":null}}
JSON
EOF
chmod +x "$TEST_ROOT/bin/curl"
IMMICH_URL='http://immich.discover.test'
DATE_AFTER='2021-01-01T00:00:00.000Z'
DATE_BEFORE='2021-02-01T00:00:00.000Z'
discover_assets 'fake-key' >"$TEST_ROOT/out-discover" 2>"$TEST_ROOT/err-discover" \
    || fail "discover_assets failed: $(cat "$TEST_ROOT/err-discover")"
grep -q "${ID_OK}"$'\tdisc.jpg' "$TEST_ROOT/out-discover" \
    || fail "discover_assets missing asset line: $(cat "$TEST_ROOT/out-discover")"
grep -q 'search/metadata' "$CURL_SPY_LOG" \
    || fail "discover_assets did not hit search/metadata"
grep -q "m=${CURL_SEARCH_TIMEOUT}" "$CURL_SPY_LOG.mvals" \
    || fail "discover_assets curl -m != CURL_SEARCH_TIMEOUT: $(cat "$CURL_SPY_LOG.mvals")"
# Spy rejects missing -m: call raw curl without -m must fail.
set +e
"$TEST_ROOT/bin/curl" -sf -X POST 'http://x/api/search/metadata' >/dev/null 2>&1
spy_nom_rc=$?
set -e
[[ "$spy_nom_rc" -ne 0 ]] \
    || fail "curl spy should fail when -m is absent"

# --- q33 P1: CLI flags override env (dest/dates/account/urls) via main ---
declare -r CLI_DEST="$TEST_ROOT/cli-dest"
declare -r CLI_HOME="$TEST_ROOT/cli-home"
mkdir -p "$CLI_HOME"
printf 'cli-key\n' >"$CLI_HOME/.immich_cliacct_key"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
: >"${CURL_SPY_LOG}.mvals"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
url=""
body=""
has_m=0
m_val=""
printf '%s\n' "$*" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) has_m=1; m_val="$2"; shift 2 ;;
        -d) body="$2"; shift 2 ;;
        -H|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
printf 'm=%s url=%s\n' "$m_val" "$url" >>"${log}.mvals"
case "$url" in
    *cli-lan.example*/api/server/ping)
        printf '200'
        exit 0
        ;;
    *cli-public.example*/api/server/ping)
        # Should not be preferred when LAN works.
        printf '200'
        exit 0
        ;;
    *env-lan.example*|*env-public.example*)
        echo "env URL used instead of CLI: $url" >&2
        exit 1
        ;;
    */api/search/metadata)
        printf 'body=%s\n' "$body" >>"${log}.bodies"
        cat <<'JSON'
{"assets":{"items":[{"id":"44444444-4444-4444-4444-444444444444","originalFileName":"cli.jpg"}],"nextPage":null}}
JSON
        exit 0
        ;;
    */api/assets/*/original)
        [[ -n "$out" ]] || exit 1
        printf 'out=%s url=%s\n' "$out" "$url" >>"${log}.outs"
        printf 'payload\n' >"$out"
        exit 0
        ;;
    *)
        echo "unexpected url: $url" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
set +e
HOME="$CLI_HOME" \
IMMICH_EXPORT_DEST="$TEST_ROOT/env-should-not-win" \
IMMICH_EXPORT_AFTER='1999-01-01T00:00:00.000Z' \
IMMICH_EXPORT_BEFORE='1999-02-01T00:00:00.000Z' \
IMMICH_LAN_URL='http://env-lan.example' \
IMMICH_PUBLIC_URL='https://env-public.example' \
"$IMMICH_EXPORT" \
    --dest "$CLI_DEST" \
    --after '2022-03-01T00:00:00.000Z' \
    --before '2022-04-01T00:00:00.000Z' \
    --account 'cliacct' \
    --lan-url 'http://cli-lan.example' \
    --public-url 'https://cli-public.example' \
    >"$TEST_ROOT/out-cli-override" 2>"$TEST_ROOT/err-cli-override"
cli_ov_rc=$?
set -e
[[ "$cli_ov_rc" -eq 0 ]] \
    || fail "CLI override main should succeed: $(cat "$TEST_ROOT/err-cli-override")"
[[ -d "$CLI_DEST/cliacct" ]] \
    || fail "--dest/--account did not create CLI dest account dir"
[[ ! -d "$TEST_ROOT/env-should-not-win" ]] \
    || fail "env DEST was used instead of --dest"
[[ -f "$CLI_DEST/cliacct/${ID_OK}_cli.jpg" ]] \
    || fail "CLI export missing downloaded asset"
grep -q 'cli-lan.example' "$CURL_SPY_LOG" \
    || fail "--lan-url not used for ping: $(cat "$CURL_SPY_LOG")"
if grep -q 'env-lan.example\|env-public.example' "$CURL_SPY_LOG"; then
    fail "env URLs used despite CLI overrides"
fi
grep -q '2022-03-01T00:00:00.000Z' "$CURL_SPY_LOG.bodies" \
    || fail "--after not in search body: $(cat "$CURL_SPY_LOG.bodies")"
grep -q '2022-04-01T00:00:00.000Z' "$CURL_SPY_LOG.bodies" \
    || fail "--before not in search body: $(cat "$CURL_SPY_LOG.bodies")"
if grep -q '1999-01-01\|1999-02-01' "$CURL_SPY_LOG.bodies"; then
    fail "env after/before used despite CLI overrides"
fi
grep -q 'Using LAN ingress' "$TEST_ROOT/out-cli-override" \
    || fail "detect_immich_url LAN message missing (CLI override run)"

# --- q33 P1 E2E main: ping OK → search one asset → download fails → exit ≠ 0 ---
declare -r E2E_DEST="$TEST_ROOT/e2e-dest"
declare -r E2E_HOME="$TEST_ROOT/e2e-home"
mkdir -p "$E2E_HOME"
printf 'e2e-key\n' >"$E2E_HOME/.immich_e2euser_key"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.outs"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CURL_SPY_LOG"
out=""
url=""
has_m=0
printf '%s\n' "$*" >>"$log"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) has_m=1; shift 2 ;;
        -H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m timeout" >&2; exit 2; }
case "$url" in
    */api/server/ping)
        printf '200'
        exit 0
        ;;
    */api/search/metadata)
        cat <<'JSON'
{"assets":{"items":[{"id":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","originalFileName":"e2e-fail.jpg"}],"nextPage":null}}
JSON
        exit 0
        ;;
    */api/assets/*/original)
        [[ -n "$out" ]] || exit 1
        printf 'out=%s url=%s\n' "$out" "$url" >>"${log}.outs"
        # Download fails after ping+search succeeded.
        exit 22
        ;;
    *)
        echo "unexpected url: $url" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
set +e
HOME="$E2E_HOME" \
"$IMMICH_EXPORT" \
    --dest "$E2E_DEST" \
    --account 'e2euser' \
    --lan-url 'http://e2e-lan.example' \
    --public-url 'https://e2e-public.example' \
    --after '2023-01-01T00:00:00.000Z' \
    --before '2023-02-01T00:00:00.000Z' \
    >"$TEST_ROOT/out-e2e" 2>"$TEST_ROOT/err-e2e"
e2e_rc=$?
set -e
[[ "$e2e_rc" -ne 0 ]] \
    || fail "E2E main download failure should exit non-zero"
grep -q 'export failed for account' "$TEST_ROOT/err-e2e" \
    || fail "missing account-failure message: $(cat "$TEST_ROOT/err-e2e")"
grep -q 'Export finished with failures' "$TEST_ROOT/err-e2e" \
    || fail "missing export-finished-with-failures die: $(cat "$TEST_ROOT/err-e2e")"
grep -q 'failed to download' "$TEST_ROOT/err-e2e" \
    || fail "missing per-asset download error: $(cat "$TEST_ROOT/err-e2e")"
grep -q 'api/server/ping' "$CURL_SPY_LOG" \
    || fail "E2E did not call detect_immich_url ping"
grep -q 'search/metadata' "$CURL_SPY_LOG" \
    || fail "E2E did not search for assets"
grep -q '/original' "$CURL_SPY_LOG" \
    || fail "E2E did not attempt download"
[[ ! -e "$E2E_DEST/e2euser/${ID_FAIL}_e2e-fail.jpg" ]] \
    || fail "E2E failed download left destination file"
# Prefer LAN when ping OK — detect_immich_url must set IMMICH_URL from LAN.
grep -q 'e2e-lan.example' "$CURL_SPY_LOG" \
    || fail "E2E ping/download did not use --lan-url"
grep -q 'Using LAN ingress' "$TEST_ROOT/out-e2e" \
    || fail "E2E missing detect_immich_url LAN message: $(cat "$TEST_ROOT/out-e2e")"

printf 'immich-export test: ok\n'
