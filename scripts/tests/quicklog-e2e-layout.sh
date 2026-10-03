#!/usr/bin/env bash
# Structural checks for the co-located Quicklog drain e2e layout (task t33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r E2E_DIR="${SCRIPT_DIR}/../quicklog/e2e"
declare -r WRAPPER="${SCRIPT_DIR}/../quicklog-drain-e2e"

die() {
    printf 'quicklog-e2e-layout test: %s\n' "$*" >&2
    exit 1
}

[[ -x "$WRAPPER" ]] || die "wrapper missing or not executable: $WRAPPER"
[[ -x "$E2E_DIR/run" ]] || die "run missing or not executable"
[[ -x "$E2E_DIR/protocol-fake" ]] || die "protocol-fake entry missing"
[[ -x "$E2E_DIR/live-s3" ]] || die "live-s3 entry missing"

for f in common.sh preflight-live.sh parser-local.sh live-s3.sh \
    protocol-fake.sh isolation.sh; do
    [[ -f "$E2E_DIR/$f" ]] || die "missing $f"
    bash -n "$E2E_DIR/$f" || die "bash -n failed for $f"
done

bash -n "$WRAPPER" || die "bash -n wrapper failed"
bash -n "$E2E_DIR/run" || die "bash -n run failed"
bash -n "$E2E_DIR/protocol-fake" || die "bash -n protocol-fake entry failed"
bash -n "$E2E_DIR/live-s3" || die "bash -n live-s3 entry failed"

# common.sh must source shared asserts; phase bodies must not redefine them.
grep -qE '^[[:space:]]*source[[:space:]].*lib/e2e-assert\.sh' \
    "$E2E_DIR/common.sh" || die "common.sh does not source lib/e2e-assert.sh"

for f in preflight-live.sh parser-local.sh live-s3.sh protocol-fake.sh \
    isolation.sh run; do
    if grep -nE '^(say|fail|assert_rc|assert_rc_nonzero|assert_eq|assert_contains|assert_not_contains|assert_exists|assert_missing)\(\)' \
        "$E2E_DIR/$f"; then
        die "$f redefines assert helpers"
    fi
done

# Mode dispatch must expose protocol-fake vs live-s3 split.
grep -q 'protocol-fake' "$E2E_DIR/run" || die "run missing protocol-fake mode"
grep -q 'live-s3' "$E2E_DIR/run" || die "run missing live-s3 mode"

# Exit-on-FAILURES contract (s33/t33): run must exit 1 when FAILURES > 0.
grep -qE 'FAILURES -eq 0' "$E2E_DIR/run" || die "run missing FAILURES summary"
grep -qE 'exit 1' "$E2E_DIR/run" || die "run missing exit 1 on FAILURES"
grep -qE 'FAILURES > 0 \? 1' "$E2E_DIR/common.sh" \
    || die "cleanup missing exit-on-FAILURES"

# Wrapper stays thin.
wc -l <"$WRAPPER" | awk '$1 > 20 { exit 1 }' \
    || die "wrapper is no longer thin ($(wc -l <"$WRAPPER") lines)"

# Helpful unknown-mode path (no Garage): should fail fast with usage, not hang.
out="$E2E_DIR/../.layout-test-out.$$"
if "$E2E_DIR/run" not-a-mode >"$out" 2>&1; then
    rm -f "$out"
    die "run accepted unknown mode"
fi
grep -q "unknown mode" "$out" || {
    cat "$out" >&2
    rm -f "$out"
    die "unknown mode did not report clearly"
}
rm -f "$out"

# shellcheck the runner (sourced libs via -x)
shellcheck -x "$E2E_DIR/run" || die "shellcheck run failed"
shellcheck -x "$WRAPPER" || die "shellcheck wrapper failed"

printf 'ok: quicklog e2e layout checks passed\n'
