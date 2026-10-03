#!/usr/bin/env bash
# Behavioral + structural checks for scripts/random-wallpaper.sh (x33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../random-wallpaper.sh"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'random-wallpaper test: %s\n' "$*" >&2
    exit 1
}

# Non-comment, non-blank lines only — greps must not match comments alone.
code_lines() {
    grep -Ev '^[[:space:]]*(#|$)' "$TARGET"
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

head -n 5 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
code_lines | grep -Eq '^set -euo pipefail$' \
    || fail "missing set -euo pipefail"

# Fail-closed find: temp file + mapfile, not process-sub / head / sort -R.
code_lines | grep -Fq 'mktemp' || fail "missing mktemp for find output"
code_lines | grep -Fq 'mapfile' || fail "missing mapfile for image pick"
code_lines | grep -Fq -- '-print0' || fail "missing find -print0 (image pick)"
code_lines | grep -Fq -- '-printf' || fail "missing find -printf (cleanup)"
code_lines | grep -Fq 'xargs -0' || fail "missing xargs -0"
if code_lines | grep -Eq '<[[:space:]]*<[[:space:]]*\('; then
    fail "image pick still uses process substitution (masks find failures)"
fi
if code_lines | grep -Eq '(^|[[:space:]])head[[:space:]]|sort[[:space:]]+-R'; then
    fail "random pick must not use head or sort -R"
fi
if code_lines | grep -Eq 'ls[[:space:]]+-1t|[^[:alnum:]_]ls[[:space:]]+-1t'; then
    fail "still uses ls -1t cleanup"
fi

# --- Behavioral fixtures ---
WALLPAPER_REL='Pictures/Pixel7ProDCIM/Irregular Ninja/irregular.ninja'
declare -r WALLPAPER_REL

setup_home() {
    local home="$1"
    mkdir -p "$home/$WALLPAPER_REL" \
        "$home/.local/share/wallpapers" \
        "$home/bin"
    # Mock dconf: record writes, succeed.
    cat >"$home/bin/dconf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DCONF_LOG:?}"
exit 0
EOF
    chmod +x "$home/bin/dconf"
}

run_wallpaper() {
    local home="$1"
    shift
    DCONF_LOG="$home/dconf.log" \
        HOME="$home" \
        PATH="$home/bin:/usr/bin:/bin" \
        "$TARGET" "$@"
}

# Negative: missing WALLPAPER_DIR
missing_home="$TEST_ROOT/missing-home"
setup_home "$missing_home"
rm -rf "${missing_home:?}/${WALLPAPER_REL:?}"
set +e
run_wallpaper "$missing_home" >"$TEST_ROOT/missing.out" 2>"$TEST_ROOT/missing.err"
missing_status=$?
set -e
((missing_status != 0)) || fail "missing WALLPAPER_DIR should exit non-zero"
grep -Fq 'Directory not found' "$TEST_ROOT/missing.err" \
    || fail "missing WALLPAPER_DIR should report Directory not found"

# Negative: empty image dir
empty_home="$TEST_ROOT/empty-home"
setup_home "$empty_home"
set +e
run_wallpaper "$empty_home" >"$TEST_ROOT/empty.out" 2>"$TEST_ROOT/empty.err"
empty_status=$?
set -e
((empty_status != 0)) || fail "empty image dir should exit non-zero"
grep -Fq 'No images found' "$TEST_ROOT/empty.err" \
    || fail "empty image dir should report No images found"

# Path-with-spaces: WALLPAPER_DIR and filename both contain spaces.
spaces_home="$TEST_ROOT/spaces home"
setup_home "$spaces_home"
# Minimal valid JPEG (1x1) so cp/file ops succeed.
printf '\xff\xd8\xff\xd9' >"$spaces_home/$WALLPAPER_REL/my photo.jpg"
: >"$spaces_home/dconf.log"
run_wallpaper "$spaces_home" >"$TEST_ROOT/spaces.out" 2>"$TEST_ROOT/spaces.err" \
    || fail "path-with-spaces pick failed"
grep -Fq 'my photo.jpg' "$TEST_ROOT/spaces.out" \
    || fail "stdout should mention spaced source filename"
mapfile -t spaced_copies < <(
    find "$spaces_home/.local/share/wallpapers" -maxdepth 1 -type f \
        -name 'random-wallpaper-*.jpg' -print
)
((${#spaced_copies[@]} == 1)) \
    || fail "expected one copied wallpaper, got ${#spaced_copies[@]}"
grep -Fq "picture-uri" "$spaces_home/dconf.log" \
    || fail "dconf write for picture-uri not invoked"

# Keep-5 / delete-oldest: >5 existing copies, run once, assert oldest gone + count 5.
keep_home="$TEST_ROOT/keep-home"
setup_home "$keep_home"
printf '\xff\xd8\xff\xd9' >"$keep_home/$WALLPAPER_REL/source.jpg"
clean_dir="$keep_home/.local/share/wallpapers"
declare -i i
for i in 1 2 3 4 5 6; do
    # Lexicographic names; mtimes increase with i so 1 is oldest.
    f="$clean_dir/random-wallpaper-00${i}.jpg"
    printf 'old-%s' "$i" >"$f"
    touch -t "2026010${i}1200" "$f"
done
oldest="$clean_dir/random-wallpaper-001.jpg"
[[ -f "$oldest" ]] || fail "fixture oldest wallpaper missing"
run_wallpaper "$keep_home" >"$TEST_ROOT/keep.out" 2>"$TEST_ROOT/keep.err" \
    || fail "keep-5 run failed"
[[ ! -f "$oldest" ]] || fail "oldest wallpaper should have been deleted"
kept_count="$(
    find "$clean_dir" -maxdepth 1 -type f -name 'random-wallpaper-*.jpg' | wc -l
)"
((kept_count == 5)) || fail "expected 5 wallpapers kept, got $kept_count"

printf 'random-wallpaper tests passed\n'
