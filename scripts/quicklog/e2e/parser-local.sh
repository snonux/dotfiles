# shellcheck shell=bash
# Local fish parser / quicklogger checks (phase 2) — no S3.
# Sourced by scripts/quicklog/e2e/run — not executed directly.

# --- phase 2: fish parser unit (no S3) ---------------------------------------------------

say "phase 2: import_content against sandbox taskwarrior"

rc=0
printf '%s' "$FIXTURE_NOTE" | run_fish 'taskwarrior::quicklog_import_content' || rc=$?
assert_rc "import_content accepts the fixture (malformed lines skipped)" 0 "$rc"
assert_eq "fixture produced $FIXTURE_GOOD tasks" "$(sandbox_task_count)" "$FIXTURE_GOOD"

assert_contains "unicode description intact" "$(sandbox_descriptions)" "buy milk ✓ ünïcode"
assert_contains "description + token kept literal" "$(sandbox_descriptions)" "+urgent fix it"
assert_contains "double spaces normalized" "$(sandbox_descriptions)" "do normalized stuff"
assert_not_contains "bare word did not become a task" "$(sandbox_descriptions)" "justoneword"
assert_eq "out-of-range due offset was a permanent skip" "$(count_desc 'due way out of range')" 0

assert_eq "trailing-r description imported exactly (F1 regression)" \
  "$(count_desc 'fix the parser')" 1
assert_eq "CRLF line: CR stripped, final r kept exactly (F1 regression)" \
  "$(count_desc 'keep final letter')" 1
assert_eq "no description contains a stray carriage return" \
  "$(sandbox_export | jq '[.[] | select(.description | contains("\r"))] | length')" 0
assert_eq "leading-dash description imported literally" \
  "$(count_desc '-dash leading minus stays')" 1

sandbox_export >"$SAN/export.json"
assert_eq "project parsed from capitalized token" \
  "$(jq -r '.[] | select(.description == "buy milk ✓ ünïcode") | .project' "$SAN/export.json")" "home"
assert_eq "comma tag parsed" \
  "$(jq -r '.[] | select(.description == "buy milk ✓ ünïcode") | .tags[0]' "$SAN/export.json")" "groceries"
assert_eq "multi tags parsed" \
  "$(jq -r '.[] | select(.description == "ship the thing") | .tags | sort | join(",")' "$SAN/export.json")" "tag1,tag2"
assert_eq "empty tag token dropped, project kept" \
  "$(jq -r '.[] | select(.description == "weird tags") | .project' "$SAN/export.json")" "foo"
assert_eq "empty tag token dropped, tag kept" \
  "$(jq -r '.[] | select(.description == "weird tags") | .tags | join(",")' "$SAN/export.json")" "bar"

due_raw=$(jq -r '.[] | select(.description == "buy milk ✓ ünïcode") | .due' "$SAN/export.json")
now_epoch=$(date +%s)
if [[ "$due_raw" =~ ^[0-9]+$ ]]; then
  if ((due_raw > now_epoch + 86400 && due_raw < now_epoch + 3 * 86400)); then
    echo "ok: due in ~2 days ($due_raw)"
  else
    fail "due offset not ~2 days: $due_raw (now $now_epoch)"
  fi
elif [[ "$due_raw" =~ ^2[0-9]{7}T[0-9]{6}Z$ ]]; then
  assert_eq "due lands 2 days out" "${due_raw:0:8}" "$(date -u -d '+2 days' +%Y%m%d)"
else
  fail "due missing or unrecognized: $due_raw"
fi

assert_eq "very long description imported intact" \
  "$(jq -r '.[] | select(.description | startswith("x")) | .description | length' "$SAN/export.json" | sort -u | tail -1)" "1000"

say "phase 2b: duplicate note content is skipped (F2 dedup, fish level)"

rc=0
printf '%s' "$FIXTURE_NOTE" | run_fish 'taskwarrior::quicklog_import_content' 2>"$SAN/dedup.err" || rc=$?
assert_rc "re-import of identical content succeeds" 0 "$rc"
assert_eq "re-import added no duplicates" "$(sandbox_task_count)" "$FIXTURE_GOOD"
assert_contains "duplicate lines reported on stderr" "$(cat "$SAN/dedup.err")" "task already pending"
assert_eq "no duplicate descriptions after re-import" \
  "$(sandbox_export | jq '[.[].description] | group_by(.) | map(select(length > 1)) | length')" 0

say "phase 2c: quicklogger scans local dirs (Notes + WORKTIME_DIR)"
mkdir -p "$SAN/home/Notes"
printf 'localone first local task\nlocaltwo second local task\nmalformed\n' >"$SAN/home/Notes/ql-e2e-local.md"
printf 'wtonly worktime task\n' >"$SAN/wt/ql-e2e-wt.md"
rc=0
# shellcheck disable=SC2016
env -i HOME="$SAN/home" TASKDATA="$SAN/taskdata" WORKTIME_DIR="$SAN/wt" QUICKLOG_HEADLESS=1 \
  QUICKLOG_FISH_CONF_DIR="$SAN/conf.d" PATH="$CHILD_PATH" \
  fish --no-config -c '
    source "$QUICKLOG_FISH_CONF_DIR/taskwarrior.fish"
    source "$QUICKLOG_FISH_CONF_DIR/quicklog.fish"
    taskwarrior::quicklogger
  ' || rc=$?
assert_rc "quicklogger run" 0 "$rc"
assert_contains "local dir task imported" "$(sandbox_descriptions)" "first local task"
assert_contains "WORKTIME_DIR task imported" "$(sandbox_descriptions)" "worktime task"
if [[ ! -e "$SAN/home/Notes/ql-e2e-local.md" && ! -e "$SAN/wt/ql-e2e-wt.md" ]]; then
  echo "ok: processed files moved away"
else
  fail "processed ql files still in place"
fi

say "phase 2d: quicklogger keeps a file whose import fails, then imports it once"

# A fake taskwarrior binary that fails while a marker file exists — a
# transient failure source that quicklogger must survive by keeping the file.
cat >"$SAN/bin/task" <<'FAKETASK'
#!/bin/bash
if [[ -e "$TASK_FAIL_MARKER" ]]; then
  echo "fake task: simulated failure" >&2
  exit 1
fi
exec /usr/bin/task "$@"
FAKETASK
chmod +x "$SAN/bin/task"
printf 'keepfail first kept line\nkeepfail second kept line\nmalformed\n' >"$SAN/home/Notes/ql-e2e-keepfail.md"
COUNT_BEFORE=$(sandbox_task_count)
touch "$SAN/fail-marker"
rc=0
# shellcheck disable=SC2016
env -i HOME="$SAN/home" TASKDATA="$SAN/taskdata" TASK_FAIL_MARKER="$SAN/fail-marker" \
  QUICKLOG_HEADLESS=1 QUICKLOG_FISH_CONF_DIR="$SAN/conf.d" \
  PATH="$SAN/bin:$CHILD_PATH" \
  fish --no-config -c '
    source "$QUICKLOG_FISH_CONF_DIR/taskwarrior.fish"
    source "$QUICKLOG_FISH_CONF_DIR/quicklog.fish"
    taskwarrior::quicklogger
  ' || rc=$?
assert_rc_nonzero "quicklogger fails while taskwarrior is broken" "$rc"
assert_eq "no tasks added during the failure" "$(sandbox_task_count)" "$COUNT_BEFORE"
if [[ -e "$SAN/home/Notes/ql-e2e-keepfail.md" ]]; then
  echo "ok: failed file stays in Notes"
else
  fail "failed file was consumed despite the failure"
fi
if compgen -G "/tmp/ql-e2e-keepfail.md" >/dev/null; then
  fail "failed file was moved to /tmp"
else
  echo "ok: failed file not moved to /tmp"
fi

rm -f "$SAN/fail-marker"
rc=0
# shellcheck disable=SC2016
env -i HOME="$SAN/home" TASKDATA="$SAN/taskdata" QUICKLOG_HEADLESS=1 \
  QUICKLOG_FISH_CONF_DIR="$SAN/conf.d" PATH="$CHILD_PATH" \
  fish --no-config -c '
    source "$QUICKLOG_FISH_CONF_DIR/taskwarrior.fish"
    source "$QUICKLOG_FISH_CONF_DIR/quicklog.fish"
    taskwarrior::quicklogger
  ' || rc=$?
assert_rc "quicklogger succeeds once unblocked" 0 "$rc"
assert_eq "kept file imported exactly once (first line)" "$(count_desc 'first kept line')" 1
assert_eq "kept file imported exactly once (second line)" "$(count_desc 'second kept line')" 1
if [[ ! -e "$SAN/home/Notes/ql-e2e-keepfail.md" ]]; then
  echo "ok: recovered file moved away"
else
  fail "recovered file still in place"
fi

say "phase 2e: due offset 0 is due today; out-of-range message states 0..10000"

# Offset 0 (due today) is the lower bound of the accepted range; it must
# import through the real parser with the due date landing exactly today.
# taskwarrior's due:Nd is now-aligned and exports as a UTC ISO timestamp, so
# the date part is UTC today — the same pattern the 2-day-out assertion
# above uses. The 99999 probe also pins the rejection message to the actual
# accepted range (0..10000), not the stale 1..10000 it once printed.
rc=0
printf '0 tagzero due zero works\n99999 tagzero due way out of range probe\n' |
  run_fish 'taskwarrior::quicklog_import_content' 2>"$SAN/duezero.err" || rc=$?
assert_rc "import_content accepts due 0 and skips the out-of-range line" 0 "$rc"
assert_contains "out-of-range line rejected with the accepted range stated" \
  "$(cat "$SAN/duezero.err")" "due offset outside 0..10000"
assert_eq "out-of-range probe line did not become a task" \
  "$(count_desc 'due way out of range probe')" 0
assert_eq "due zero task imported exactly once" "$(count_desc 'due zero works')" 1
due_zero_raw=$(sandbox_export | jq -r '.[] | select(.description == "due zero works") | .due')
if [[ "$due_zero_raw" =~ ^2[0-9]{7}T[0-9]{6}Z$ ]]; then
  assert_eq "due offset 0 lands exactly today" "${due_zero_raw:0:8}" "$(date -u +%Y%m%d)"
elif [[ "$due_zero_raw" =~ ^[0-9]+$ ]]; then
  # Defensive epoch form (same now-aligned semantics): within one day of now
  now_epoch=$(date +%s)
  if ((due_zero_raw >= now_epoch - 3600 && due_zero_raw <= now_epoch + 86400)); then
    echo "ok: due offset 0 lands today (epoch $due_zero_raw)"
  else
    fail "due offset 0 not today: $due_zero_raw (now $now_epoch)"
  fi
else
  fail "due zero task missing or unrecognized due: $due_zero_raw"
fi
