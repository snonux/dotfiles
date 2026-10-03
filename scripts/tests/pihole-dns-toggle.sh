#!/usr/bin/env bash
# Checks for scripts/pihole-dns-toggle strict-mode header (task x33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../pihole-dns-toggle"

fail() {
    printf 'pihole-dns-toggle test: %s\n' "$*" >&2
    exit 1
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

head -n 5 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
grep -Eq '^set -euo pipefail$' "$TARGET" \
    || fail "missing set -euo pipefail"
if grep -Eq '^#!/bin/bash$' "$TARGET"; then
    fail "still uses #!/bin/bash"
fi
if grep -Eq '^set -e$' "$TARGET"; then
    fail "still uses bare set -e"
fi

printf 'pihole-dns-toggle tests passed\n'
