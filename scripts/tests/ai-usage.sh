#!/usr/bin/env bash
# Checks for scripts/ai-usage: Codex + Claude sections, formats, error paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../ai-usage"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'ai-usage test: %s\n' "$*" >&2
    exit 1
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -S warning "$TARGET" || fail "shellcheck failed"

# Fixture PATH: real coreutils minus codex, plus fake curl / fake codex.
declare -r BIN="$TEST_ROOT/bin"
mkdir -p "$BIN" "$BIN-args"
for tool in bash env jq sed timeout cat; do
    ln -s "$(command -v "$tool")" "$BIN/$tool" \
        || fail "cannot symlink $tool into the fixture PATH"
done

# Fake curl: prints $FAKE_BODY + $FAKE_STATUS, or exits $FAKE_CURL_EXIT.
# Records its argv and reads the curl config from stdin so tests can assert
# on the request that was made.
cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
[ -n "${FAKE_CURL_EXIT:-}" ] && exit "$FAKE_CURL_EXIT"
printf '%s\n' "$@" >"${CURL_ARGV_FILE:?}"
cat >"${CURL_ARGS_FILE:?}"
cat "$FAKE_BODY"
echo "$FAKE_STATUS"
EOF
chmod +x "$BIN/curl"

# Fake Claude Code sign-in with a dummy token that must never be printed.
declare -r CLAUDE="$TEST_ROOT/claude"
mkdir -p "$CLAUDE"
printf '%s\n' '{"claudeAiOauth":{"accessToken":"test-token-secret","subscriptionType":"max"}}' \
    >"$CLAUDE/.credentials.json"

declare -r CLAUDE_EMPTY="$TEST_ROOT/claude-empty"
mkdir -p "$CLAUDE_EMPTY"

# Raw /api/oauth/usage body: window objects are top-level keys (the
# rate_limits wrapper and subscription_type are added client-side).
declare -r CLAUDE_OK='{"five_hour":{"utilization":62.4,"resets_at":1793300400},"seven_day":{"utilization":35,"resets_at":"2026-11-02T00:00:00Z"}}'

run() {
    PATH="$BIN" CLAUDE_CONFIG_DIR="$CLAUDE" \
        CURL_ARGV_FILE="$TEST_ROOT/curl-argv" \
        CURL_ARGS_FILE="$TEST_ROOT/curl-args" \
        "$@"
}

# --- Claude happy path (Codex absent) ---------------------------------------

FAKE_BODY="$TEST_ROOT/claude-ok.json"
printf '%s\n' "$CLAUDE_OK" >"$FAKE_BODY"
export FAKE_BODY FAKE_STATUS=200

unset FAKE_CODEX FAKE_CURL_EXIT || true

out=$(run timeout 20 "$TARGET" --color never) \
    || fail "text run failed against the happy-path fixture"
grep -Fq 'Claude usage (max)' <<<"$out" \
    || fail "text: missing Claude header: $out"
grep -Fq 'Codex usage unavailable (codex is not on PATH)' <<<"$out" \
    || fail "text: missing Codex-unavailable line: $out"
grep -Fq '5h [' <<<"$out" || fail "text: missing 5h window: $out"
grep -Fq '38% left · 62% used' <<<"$out" \
    || fail "text: 5h floor/remaining math wrong: $out"
grep -Fq '↳ resets 2026-10-29T19:00:00Z' <<<"$out" \
    || fail "text: epoch resets_at not formatted: $out"
grep -Fq '7d [' <<<"$out" || fail "text: missing 7d window: $out"
grep -Fq '65% left' <<<"$out" || fail "text: 7d remaining wrong: $out"
grep -Fq '2026-11-02T00:00:00Z' <<<"$out" \
    || fail "text: ISO resets_at not passed through: $out"
if grep -Fq 'test-token-secret' <<<"$out"; then
    fail "text: OAuth token leaked into stdout"
fi
# The token must reach curl through the stdin config, never through argv.
grep -Fq 'Authorization: Bearer test-token-secret' "$TEST_ROOT/curl-args" \
    || fail "curl: request config missing the Authorization header"
grep -Fq 'https://api.anthropic.com/api/oauth/usage' "$TEST_ROOT/curl-args" \
    || fail "curl: wrong usage endpoint"
# The emitted config must parse with real curl (guards regressions like a
# literal newline inside the write-out string); --version skips the request.
curl -K "$TEST_ROOT/curl-args" --version >/dev/null 2>&1 \
    || fail "curl: emitted config is not parseable by real curl"
if grep -Fq 'test-token-secret' "$TEST_ROOT/curl-argv"; then
    fail "curl: OAuth token exposed in the command line"
fi
grep -Fq -- '--config' "$TEST_ROOT/curl-argv" \
    || fail "curl: not invoked with --config -"

out=$(run timeout 20 "$TARGET" --format remaining 2>"$TEST_ROOT/err") \
    || fail "remaining run failed against the happy-path fixture"
grep -Fxq 'claude 5h 38' <<<"$out" \
    || fail "remaining: 5h line wrong: $out"
grep -Fxq 'claude 7d 65' <<<"$out" \
    || fail "remaining: 7d line wrong: $out"
if grep -Fq 'claude' "$TEST_ROOT/err"; then
    fail "remaining: Claude warning on stderr despite a successful fetch"
fi
grep -Fq 'ai-usage: Codex unavailable' "$TEST_ROOT/err" \
    || fail "remaining: missing Codex-unavailable warning on stderr"

out=$(run timeout 20 "$TARGET" --format json) \
    || fail "json run failed against the happy-path fixture"
jq -e '.claude.five_hour.utilization == 62.4' \
    >/dev/null <<<"$out" || fail "json: claude payload wrong: $out"
jq -e '.codex.error' >/dev/null <<<"$out" \
    || fail "json: codex error object missing: $out"
if grep -Fq 'test-token-secret' <<<"$out"; then
    fail "json: OAuth token leaked into stdout"
fi

# --- Regression: empty five_hour must not shift the seven_day fields --------
# (TSV/tab parsing collapsed empty fields before the join("|") switch.)

FAKE_BODY="$TEST_ROOT/claude-no5h.json"
printf '%s\n' '{"five_hour":{"utilization":null,"resets_at":null},"seven_day":{"utilization":20,"resets_at":1793300400}}' \
    >"$FAKE_BODY"

out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed with a null five_hour utilization"
if grep -Fq '5h [' <<<"$out"; then
    fail "text: 5h line shown for null utilization"
fi
grep -Fq '7d [' <<<"$out" || fail "text: 7d line missing: $out"
grep -Fq '80% left' <<<"$out" \
    || fail "text: 7d remaining wrong after null 5h: $out"

out=$(run timeout 20 "$TARGET" --format remaining 2>/dev/null) \
    || fail "remaining failed with a null five_hour utilization"
if grep -Fq 'claude 5h' <<<"$out"; then
    fail "remaining: 5h line shown for null utilization"
fi
grep -Fxq 'claude 7d 80' <<<"$out" \
    || fail "remaining: 7d line wrong after null 5h: $out"

# --- Claude with no subscription windows ------------------------------------

FAKE_BODY="$TEST_ROOT/claude-nolimits.json"
printf '%s\n' '{"five_hour":null,"seven_day":null}' >"$FAKE_BODY"

out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed with null windows"
grep -Fq 'no subscription usage data' <<<"$out" \
    || fail "text: missing no-data line: $out"

# --- Claude in-band error: 200 body without any window key --------------------

FAKE_BODY="$TEST_ROOT/claude-inband.json"
printf '%s\n' '{"type":"error"}' >"$FAKE_BODY"

out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed with an in-band error body"
grep -Fq 'Claude usage unavailable (Claude returned an unexpected usage response)' \
    <<<"$out" || fail "text: in-band error message wrong: $out"

# --- Claude error paths ------------------------------------------------------

fake_status_check() {
    # $1 = FAKE_STATUS, $2 = expected substring of the unavailable message,
    # $3 = expected JSON .claude.error substring.
    FAKE_STATUS=$1
    out=$(run timeout 20 "$TARGET" --color never) \
        || fail "run failed with HTTP $1"
    grep -Fq "Claude usage unavailable ($2)" <<<"$out" \
        || fail "text: HTTP $1 message wrong: $out"
    out=$(run timeout 20 "$TARGET" --format json)
    jq -e --arg m "$3" '.claude.error | index($m) != null' \
        >/dev/null <<<"$out" || fail "json: HTTP $1 error wrong: $out"
    out=$(run timeout 20 "$TARGET" --format remaining 2>/dev/null)
    if grep -Fq 'claude' <<<"$out"; then
        fail "remaining: claude lines shown after HTTP $1"
    fi
}

FAKE_BODY="$TEST_ROOT/claude-err.json"
printf '%s\n' '{"type":"error","error":{"type":"rate_limit_error"}}' >"$FAKE_BODY"
fake_status_check 429 'the Anthropic usage API is rate limiting requests' \
    'rate limiting'
fake_status_check 401 \
    'the Claude subscription is not usable (re-sign-in or check billing)' \
    'not usable'
fake_status_check 403 \
    'the Claude subscription is not usable (re-sign-in or check billing)' \
    'not usable'
fake_status_check 500 'the Anthropic usage API returned HTTP 500' \
    'returned HTTP 500'

export FAKE_CURL_EXIT=7
out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed when curl dies"
grep -Fq 'Claude usage unavailable (could not reach the Anthropic usage API)' \
    <<<"$out" || fail "text: curl-failure message wrong: $out"
unset FAKE_CURL_EXIT

FAKE_STATUS=200
printf 'not json at all\n' >"$FAKE_BODY"
out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed on a malformed response body"
grep -Fq 'Claude usage unavailable (Claude returned an unexpected usage response)' \
    <<<"$out" || fail "text: malformed-body message wrong: $out"

out=$(PATH="$BIN" CLAUDE_CONFIG_DIR="$CLAUDE_EMPTY" \
    timeout 20 "$TARGET" --color never) \
    || fail "run failed with an empty config dir"
grep -Fq 'Claude usage unavailable (Claude Code is not signed in)' \
    <<<"$out" || fail "text: missing-credentials message wrong: $out"

# --- Codex section ------------------------------------------------------------

# Fake codex app-server, driven by $FAKE_CODEX: ok | die | nullresult.
cat >"$BIN/codex" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_CODEX:-ok}" in
    die) exit 1 ;;
    nullresult)
        while IFS= read -r line; do
            case $line in
                *'"initialize"'*) printf '%s\n' '{"id":1,"result":{}}' ;;
                *'rateLimits/read'*) printf '%s\n' '{"id":2,"result":null}' ;;
            esac
        done
        ;;
    ok)
        while IFS= read -r line; do
            case $line in
                *'"initialize"'*) printf '%s\n' '{"id":1,"result":{}}' ;;
                *'rateLimits/read'*)
                    printf '%s\n' '{"id":2,"result":{"accountId":"acct-should-be-dropped","rateLimits":{"planType":"testplan","primary":{"usedPercent":25,"resetsAt":1793300400}}}}'
                    ;;
            esac
        done
        ;;
esac
EOF
chmod +x "$BIN/codex"

FAKE_BODY="$TEST_ROOT/claude-ok.json"
printf '%s\n' "$CLAUDE_OK" >"$FAKE_BODY"
export FAKE_CODEX=ok

out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed with the fake codex app server"
grep -Fq 'Codex usage (testplan)' <<<"$out" \
    || fail "text: missing Codex header: $out"
grep -Fq '75% left · 25% used' <<<"$out" \
    || fail "text: Codex remaining math wrong: $out"

out=$(run timeout 20 "$TARGET" --format json)
jq -e '.codex.rateLimits.planType == "testplan"' \
    >/dev/null <<<"$out" || fail "json: codex payload wrong: $out"
jq -e 'has("accountId") | not' \
    >/dev/null <<<"$out" || fail "json: codex accountId was not dropped"

out=$(run timeout 20 "$TARGET" --format remaining 2>/dev/null)
grep -Fxq 'codex 75' <<<"$out" \
    || fail "remaining: codex line wrong: $out"

export FAKE_CODEX=die
out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed when the codex app server dies"
grep -Fq 'Codex usage unavailable (could not read Codex rate limits)' \
    <<<"$out" || fail "text: dead-codex message wrong: $out"

export FAKE_CODEX=nullresult
out=$(run timeout 20 "$TARGET" --color never) \
    || fail "run failed when codex returns a null result"
grep -Fq 'Codex usage unavailable (could not read Codex rate limits)' \
    <<<"$out" || fail "text: null-result codex message wrong: $out"
unset FAKE_CODEX

# --- Colour handling ----------------------------------------------------------

out=$(run timeout 20 "$TARGET" --color never)
if grep -q $'\033' <<<"$out"; then
    fail "--color never still emits escape codes"
fi
out=$(run timeout 20 "$TARGET" --color always)
grep -q $'\033\[36m' <<<"$out" \
    || fail "--color always emits no cyan header colour"

# --- Argument handling ----------------------------------------------------------

if run timeout 20 "$TARGET" --format bogus 2>"$TEST_ROOT/err"; then
    fail "unknown format accepted"
fi
grep -Fq 'unknown format: bogus' "$TEST_ROOT/err" \
    || fail "unknown-format message wrong: $(cat "$TEST_ROOT/err")"

if run timeout 20 "$TARGET" --nope 2>"$TEST_ROOT/err"; then
    fail "unknown argument accepted"
fi
grep -Fq 'unknown argument: --nope' "$TEST_ROOT/err" \
    || fail "unknown-argument message wrong: $(cat "$TEST_ROOT/err")"

if run timeout 20 "$TARGET" --help >"$TEST_ROOT/out"; then
    grep -Fq 'Usage:' "$TEST_ROOT/out" \
        || fail "--help does not print the usage block"
else
    fail "--help exited nonzero"
fi

printf 'ok: ai-usage checks passed\n'