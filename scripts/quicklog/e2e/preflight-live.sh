# shellcheck shell=bash
# Live preflight (phase 0): tools, dart CLI matrix, timer, fingerprints, empty bucket.
# Sourced by scripts/quicklog/e2e/run — not executed directly.

# --- phase 0: preflight -------------------------------------------------------------

say "phase 0: preflight"

for tool in fish jq flock timeout systemctl sqlite3 pgrep; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$PROGRAM: missing tool: $tool" >&2
    exit 1
  }
done
[[ -x "$DART" ]] || { echo "$PROGRAM: missing Dart SDK at $DART" >&2; exit 1; }
[[ -x "$REAL_TASK" ]] || { echo "$PROGRAM: missing $REAL_TASK" >&2; exit 1; }
[[ -r "$CREDS" ]] || { echo "$PROGRAM: missing $CREDS" >&2; exit 1; }
[[ -d "$REPO" ]] || { echo "$PROGRAM: missing Quicklog repo $REPO" >&2; exit 1; }
[[ -r "$REPO/tool/put_note.dart" ]] || { echo "$PROGRAM: missing tool/put_note.dart in $REPO" >&2; exit 1; }

# Warm the package resolution once, so no `dart run` below can print
# dependency-resolution noise mid-test: the wrapper's --import protocol
# desyncs on stray stdout, and bucket_keys() parses dart's stdout directly.
env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" \
  "$DART" pub get >/dev/null 2>&1 \
  || echo "$PROGRAM: WARNING: dart pub get failed; dart run may print resolution noise" >&2

say "phase 0b: dart CLI arg matrix (no credentials, no S3)"

# Usage errors must exit 64; parseable invocations proceed to the credential
# check and exit 1 (GARAGE_* deliberately absent from the environment).
# shellcheck disable=SC2086
for bad in "--limit 0" "--delete k --limit 2" "--delete" "--dest" "--import --bogus" "--keys --only x" "--import --only a,,b"; do
  rc=0
  env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" \
    "$DART" run bin/quicklog_drain.dart $bad >/dev/null 2>&1 || rc=$?
  assert_rc "usage error for: $bad" 64 "$rc"
done
stderr_capture=$(mktemp)
# shellcheck disable=SC2086
env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" \
  "$DART" run bin/quicklog_drain.dart --limit 0 >"$stderr_capture" 2>&1
assert_contains "usage error prints usage text" "$(cat "$stderr_capture")" "Usage:"
rm -f "$stderr_capture"
# shellcheck disable=SC2086
for good in "--import" "--import --only ql-x.md,ql-y.md" "--keys" "--dest /tmp/ql-e2e-nonexistent" "--delete ql-x.md"; do
  rc=0
  env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" \
    "$DART" run bin/quicklog_drain.dart $good >/dev/null 2>&1 || rc=$?
  assert_rc "parsed, fails on missing creds: $good" 1 "$rc"
done
# Whitespace around --only parts must not turn into a usage error (the
# parts are trimmed) — it cannot go through the unquoted $good loop above.
rc=0
env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" \
  "$DART" run bin/quicklog_drain.dart --import --only "a, b" >/dev/null 2>&1 || rc=$?
assert_rc "parsed, fails on missing creds: --import --only 'a, b'" 1 "$rc"

if systemctl --user is-active --quiet quicklog-drain.timer; then
  TIMER_WAS_ACTIVE=true
  echo "quicklog-drain.timer is active — it will be stopped for the test"
fi

REAL_DB_BEFORE=$(real_db_fingerprint)
REAL_DB_SEM_BEFORE=$(real_db_semantics)
REAL_NOTES_BEFORE=$(real_notes_fingerprint)
REAL_STAMP_BEFORE=$(real_due_stamp_fingerprint)
BUCKET_BEFORE=$(bucket_keys | sort)

if [[ -n "$BUCKET_BEFORE" ]]; then
  echo "$PROGRAM: bucket has pending notes; drain them before running the E2E:" >&2
  printf '%s\n' "$BUCKET_BEFORE" >&2
  exit 1
fi
echo "ok: bucket empty, real data fingerprinted"
