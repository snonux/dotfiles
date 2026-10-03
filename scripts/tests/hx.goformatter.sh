#!/usr/bin/env bash
# Checks for scripts/hx.goformatter: pipefail so goimports failures surface (x33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../hx.goformatter"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'hx.goformatter test: %s\n' "$*" >&2
    exit 1
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

head -n 5 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
grep -Eq '^set -euo pipefail$' "$TARGET" \
    || fail "missing set -euo pipefail"

mkdir -p "$TEST_ROOT/bin"

# goimports fails; gofumpt would succeed on empty stdin — pipefail must fail.
cat >"$TEST_ROOT/bin/goimports" <<'EOF'
#!/usr/bin/env bash
printf 'goimports mock: forced failure\n' >&2
exit 1
EOF
cat >"$TEST_ROOT/bin/gofumpt" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 0
EOF
chmod +x "$TEST_ROOT/bin/goimports" "$TEST_ROOT/bin/gofumpt"

set +e
printf 'package main\n' \
    | PATH="$TEST_ROOT/bin:$PATH" "$TARGET" >/dev/null 2>&1
status=$?
set -e
((status != 0)) || fail "goimports failure was masked (exit 0)"

# Both stages succeed: stdout must pass through.
cat >"$TEST_ROOT/bin/goimports" <<'EOF'
#!/usr/bin/env bash
cat
exit 0
EOF
cat >"$TEST_ROOT/bin/gofumpt" <<'EOF'
#!/usr/bin/env bash
cat
exit 0
EOF
chmod +x "$TEST_ROOT/bin/goimports" "$TEST_ROOT/bin/gofumpt"

# Write to files so trailing newlines are not stripped by $(...).
printf 'ok\n' | PATH="$TEST_ROOT/bin:$PATH" "$TARGET" >"$TEST_ROOT/out"
printf 'ok\n' >"$TEST_ROOT/expected"
cmp -s "$TEST_ROOT/out" "$TEST_ROOT/expected" \
    || fail "unexpected formatter output: $(cat -A "$TEST_ROOT/out")"

printf 'hx.goformatter tests passed\n'
