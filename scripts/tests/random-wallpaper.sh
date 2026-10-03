#!/usr/bin/env bash
# Checks for scripts/random-wallpaper.sh strict mode + null-safe cleanup (x33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../random-wallpaper.sh"

fail() {
    printf 'random-wallpaper test: %s\n' "$*" >&2
    exit 1
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

head -n 5 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
grep -Eq '^set -euo pipefail$' "$TARGET" \
    || fail "missing set -euo pipefail"

# Cleanup must use null-delimited find|xargs, not ls|xargs.
grep -Fq -- '-print0' "$TARGET" || fail "missing find -print0 (image pick)"
grep -Fq -- '-printf' "$TARGET" || fail "missing find -printf (cleanup)"
grep -Fq 'xargs -0' "$TARGET" || fail "missing xargs -0"
if grep -Eq 'ls[[:space:]]+-1t.*xargs' "$TARGET"; then
    fail "still uses ls|xargs cleanup"
fi
if grep -Eq '[^[:alnum:]_]ls[[:space:]]+-1t' "$TARGET" \
    || grep -Eq '^ls[[:space:]]+-1t' "$TARGET"; then
    fail "still uses ls -1t"
fi

printf 'random-wallpaper tests passed\n'
