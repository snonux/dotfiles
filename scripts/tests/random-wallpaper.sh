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

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

# Kept as a source check: env-bash over /bin/bash only matters on hosts
# without /bin/bash, so this machine cannot observe it.
head -n 1 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
# Everything else is checked by running the script below: a failing find
# fails closed, names with spaces or newlines survive the pick and the
# cleanup, the pick is random, and cleanup keeps the 5 newest by mtime.

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

# Cleanup orders by mtime, not by name, and copes with spaces: the names
# run opposite to the mtimes, so the oldest copy is the one sorting last.
mtime_home="$TEST_ROOT/mtime-home"
setup_home "$mtime_home"
printf '\xff\xd8\xff\xd9' >"$mtime_home/$WALLPAPER_REL/source.jpg"
mtime_dir="$mtime_home/.local/share/wallpapers"
for i in 1 2 3 4 5 6; do
    f="$mtime_dir/random-wallpaper-old copy $((7 - i)).jpg"
    printf 'old-%s' "$i" >"$f"
    touch -t "2026010${i}1200" "$f"
done
run_wallpaper "$mtime_home" >/dev/null 2>"$TEST_ROOT/mtime.err" \
    || fail "mtime cleanup run failed: $(cat "$TEST_ROOT/mtime.err")"
[[ ! -e "$mtime_dir/random-wallpaper-old copy 6.jpg" ]] \
    || fail "oldest-by-mtime spaced copy was kept"
[[ -e "$mtime_dir/random-wallpaper-old copy 1.jpg" ]] \
    || fail "newest old copy was deleted (cleanup sorted by name?)"
mtime_count="$(
    find "$mtime_dir" -maxdepth 1 -type f -name 'random-wallpaper-*.jpg' | wc -l
)"
((mtime_count == 5)) || fail "expected 5 wallpapers kept, got $mtime_count"

# A newline in the image name survives the pick (null-delimited list).
nl_home="$TEST_ROOT/nl-home"
setup_home "$nl_home"
nl_name=$'two\nlines.jpg'
printf '\xff\xd8\xff\xd9' >"$nl_home/$WALLPAPER_REL/$nl_name"
run_wallpaper "$nl_home" >"$TEST_ROOT/nl.out" 2>"$TEST_ROOT/nl.err" \
    || fail "newline-name pick failed: $(cat "$TEST_ROOT/nl.err")"
[[ "$(cat "$TEST_ROOT/nl.out")" == *"(copied from $nl_home/$WALLPAPER_REL/$nl_name)" ]] \
    || fail "newline name mangled: $(cat "$TEST_ROOT/nl.out")"

# The pick is random, not always the first file: 30 runs over 2 images
# must pick both (all-same by chance: 2^-29).
pick_home="$TEST_ROOT/pick-home"
setup_home "$pick_home"
printf '\xff\xd8\xff\xd9' >"$pick_home/$WALLPAPER_REL/a.jpg"
printf '\xff\xd8\xff\xd9' >"$pick_home/$WALLPAPER_REL/b.jpg"
: >"$TEST_ROOT/picks"
for i in $(seq 1 30); do
    run_wallpaper "$pick_home" >>"$TEST_ROOT/picks" 2>/dev/null \
        || fail "pick run $i failed"
done
grep -Fq '/a.jpg)' "$TEST_ROOT/picks" || fail "a.jpg never picked in 30 runs"
grep -Fq '/b.jpg)' "$TEST_ROOT/picks" || fail "b.jpg never picked in 30 runs"

# A find that fails during the pick fails the run closed, even when it
# already printed a usable image: no wallpaper is set. The fake find fails
# only for the pick (-print0) and runs the real find otherwise.
ff_home="$TEST_ROOT/findfail-home"
setup_home "$ff_home"
printf '\xff\xd8\xff\xd9' >"$ff_home/$WALLPAPER_REL/ok.jpg"
real_find=$(command -v find)
cat >"$ff_home/bin/find" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
    if [[ "\$arg" == -print0 ]]; then
        printf '%s\0' "\$1/ok.jpg"
        echo 'find mock: simulated failure' >&2
        exit 1
    fi
done
exec '$real_find' "\$@"
EOF
chmod +x "$ff_home/bin/find"
: >"$ff_home/dconf.log"
if run_wallpaper "$ff_home" >/dev/null 2>"$TEST_ROOT/findfail.err"; then
    fail "failing find during the pick exited 0"
fi
[[ ! -s "$ff_home/dconf.log" ]] \
    || fail "wallpaper set although find failed: $(cat "$ff_home/dconf.log")"

printf 'random-wallpaper tests passed\n'
