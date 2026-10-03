#!/usr/bin/env bash
# Negative/repro checks for scripts/gvim argv safety (task e33).
#
# Mock ghostty only records argv; it never execs a shell. Regression
# signal is therefore argv shape, not filesystem side effects from -e.
# Older ghostty (<1.2.0) re-joined -e args into sh -c; this suite does
# not claim to reproduce that runtime — see scripts/gvim header.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r GVIM="${SCRIPT_DIR}/../gvim"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'gvim test: %s\n' "$*" >&2
    exit 1
}

mkdir -p "$TEST_ROOT/bin"

# Mock ghostty: record argv null-separated; never exec a real terminal.
cat >"$TEST_ROOT/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${ARGV_DUMP:?ARGV_DUMP unset}"
printf '%s\0' "$@" >"$ARGV_DUMP"
EOF
chmod +x "$TEST_ROOT/bin/ghostty"

export PATH="$TEST_ROOT/bin:$PATH"
export ARGV_DUMP="$TEST_ROOT/argv"

# Fixture path with spaces, shell metacharacters, and a command substitution.
# Under the old `ghostty -e "hx $FILE_PATH"` form these alter the command.
declare -r EVIL_PATH="$TEST_ROOT/evil \$HOME; touch pwned \`id\` file.txt"
: >"$EVIL_PATH"

bash -n "$GVIM" || fail "bash -n failed"
shellcheck -x "$GVIM" || fail "shellcheck failed"

# Document buggy glued-string form: path becomes one -e string argument.
# (Honest about the mock: no shell runs, so no side-effect file appears.)
ARGV_DUMP="$TEST_ROOT/argv_buggy"
ghostty -e "hx $EVIL_PATH" || fail "buggy repro mock failed"
mapfile -d '' -t buggy_argv <"$ARGV_DUMP"
[[ "${buggy_argv[0]}" == '-e' ]] || fail "buggy argv[0] unexpected"
[[ "${buggy_argv[1]}" == "hx $EVIL_PATH" ]] || fail \
    "buggy repro did not glue path into -e string: ${buggy_argv[1]@Q}"

# Fixed form: path must be its own argv after hx -- (not glued into -e).
ARGV_DUMP="$TEST_ROOT/argv"
"$GVIM" unused "$EVIL_PATH" || fail "gvim exited non-zero"

mapfile -d '' -t argv <"$ARGV_DUMP"
((${#argv[@]} >= 4)) || fail "expected >=4 argv entries, got ${#argv[@]}"

[[ "${argv[0]}" == '-e' ]] || fail "argv[0]=${argv[0]@Q}, want -e"
[[ "${argv[1]}" == 'hx' ]] || fail "argv[1]=${argv[1]@Q}, want hx"
[[ "${argv[2]}" == '--' ]] || fail "argv[2]=${argv[2]@Q}, want --"
[[ "${argv[3]}" == "$EVIL_PATH" ]] || fail \
    "path not a single argv: got ${argv[3]@Q}"
[[ "${argv[1]}" != "hx $EVIL_PATH" ]] || fail \
    "fixed form still glues path into -e string"

# Missing path must fail closed (set -u / ${2:?}).
if "$GVIM" unused 2>/dev/null; then
    fail "gvim succeeded with missing file path"
fi

# Empty second arg must fail closed (qutebrowser-style $2 contract).
if "$GVIM" unused "" 2>/dev/null; then
    fail "gvim succeeded with empty file path"
fi

# Structural guard: must not interpolate FILE_PATH inside a shell string.
if grep -Eq 'hx[[:space:]]+\$\{?FILE_PATH' "$GVIM"; then
    fail "gvim still embeds FILE_PATH in a shell string for hx"
fi

printf 'gvim test: ok\n'
