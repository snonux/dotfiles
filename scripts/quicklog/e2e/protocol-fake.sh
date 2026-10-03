# shellcheck shell=bash
# Protocol failure paths with a fake dart emitter (phase 6) — no S3.
# Sourced by scripts/quicklog/e2e/run — not executed directly.

# --- phase 6: protocol failure paths without S3 (fake emitter) ------------------------------

say "phase 6: protocol failures with the fake dart emitter"

# The fake emulates bin/quicklog_drain.dart --import: it streams one JSON
# line per staged object, reads one ack per note, and deletes the object
# file only on an ok-ack with a matching key — the same semantics the real
# tool has (unit-tested in the quicklog repo). A marker file makes it emit a
# garbage line first (malformed-stream-line scenario).
mkdir -p "$SAN/home/fake-dart/objects"
cat >"$SAN/bin/fakedart" <<'FAKEDART'
#!/bin/bash
set -u
if [[ "${1:-}" == "pub" ]]; then
  exit 0 # the wrapper pre-resolves with `dart pub get`; accept and no-op
fi
if [[ "${1:-}" != "run" ]]; then
  exit 64
fi
shift # run
shift # bin/quicklog_drain.dart — remaining flags (e.g. --only) don't matter:
      # the fake's bucket only ever holds the keys the harness staged.
state="$HOME/fake-dart"
log() { printf '%s\n' "$*" >>"$state/log"; }

if [[ -f "$state/garbage-first" ]]; then
  printf 'this is not a json protocol line\n'
  log "emitted garbage"
fi

for obj in $(ls "$state/objects" | sort); do
  content_json=$(jq -Rs . <"$state/objects/$obj")
  printf '{"key":"%s","content":%s}\n' "$obj" "$content_json"
  log "emitted $obj"
  if ! IFS= read -r ack; then
    log "aborted: consumer went away after $obj"
    exit 1
  fi
  ack_key=$(jq -r '.key // empty' <<<"$ack" 2>/dev/null) || ack_key=""
  ack_ok=$(jq -r '.ok // empty' <<<"$ack" 2>/dev/null) || ack_ok=""
  if [[ "$ack_key" != "$obj" ]]; then
    log "desync abort: ack for '$ack_key' but expected '$obj'"
    exit 1
  fi
  if [[ "$ack_ok" == "true" ]]; then
    rm -f "$state/objects/$obj"
    log "deleted $obj"
  else
    log "kept $obj"
  fi
done
exit 0
FAKEDART
chmod +x "$SAN/bin/fakedart"

say "phase 6a: malformed stream line — wrapper aborts, emitter keeps its objects"

KEY6A=$(make_key 15)
printf 'tagonly fakedart malformed path line\n' >"$SAN/home/fake-dart/objects/$KEY6A"
touch "$SAN/home/fake-dart/garbage-first"
rc=0
# Pass --only explicitly: protocol-fake objects are file-staged (not put_note),
# so TEST_KEYS may be empty when this mode runs alone.
run_script --dart "$SAN/bin/fakedart" --only "$KEY6A" >/dev/null 2>&1 || rc=$?
assert_rc_nonzero "wrapper exits nonzero on a malformed stream line" "$rc"
assert_contains "fake dart saw the desync" "$(cat "$SAN/home/fake-dart/log")" "desync abort"
if [[ -e "$SAN/home/fake-dart/objects/$KEY6A" ]]; then
  echo "ok: emitter kept the object (nothing deleted)"
else
  fail "emitter deleted an object despite the desync"
fi
assert_eq "note consumed before the abort imported exactly once" \
  "$(count_desc 'fakedart malformed path line')" 1

say "phase 6b: consumer death mid-stream — acked object deleted, current object kept"

rm -f "$SAN/home/fake-dart/garbage-first" "$SAN/home/fake-dart/log"
# The malformed-line object from 6a served its purpose (it was asserted kept;
# its line was imported into the sandbox) — remove it so the 6b background
# run only deals with the two consumer-death keys.
rm -f "$SAN/home/fake-dart/objects/$KEY6A"
KEY6B1=$(make_key 16)
KEY6B2=$(make_key 17)
printf 'tagonly fakedart first acked note\n' >"$SAN/home/fake-dart/objects/$KEY6B1"
{
  echo 'fakedart second good line'
  echo 'justoneword'
  # Fresh descriptions (never used by earlier phases): colliding with
  # earlier fixtures would make the pending-description dedup skip these
  # lines on first import and break the exactly-once assertions below.
  seq -f 'fakedart fakebulk task %03.0f' 1 60
} >"$SAN/home/fake-dart/objects/$KEY6B2"
FAKE6B_GOODS=61 # 1 second-line + 60 fakebulk lines

# The kill lands at a deterministic moment: the import fish runs against a
# fake `task` that blocks the first add of the second note while a marker
# exists, so the harness kills the wrapper — the consumer of the dart
# stream — while that note is provably mid-import (the same SIGTERM the
# service's timeout wrapper would deliver). Unblocking afterwards lets the
# orphaned import finish all 61 lines, so the retry must dedup against them.
gen_fake_task "$SAN/bin6b" "second good line" "$SAN/6b-block" "$SAN/6b-tasklog"
touch "$SAN/6b-block"
build_wrapper_env "" "$SAN/bin/fakedart" "$SAN/bin6b:$CHILD_PATH"
env "${WRAPPER_ENV[@]}" "$DOTFILES/scripts/quicklog/drain" --only "$KEY6B1,$KEY6B2" &
WPID=$!
if kill_when_blocked "$WPID" "$SAN/6b-tasklog"; then
  echo "ok: wrapper killed while the import was blocked mid-add"
else
  fail "fake task never blocked — deterministic kill window broken"
fi
wait "$WPID" 2>/dev/null
WPID_RC=$?
assert_rc_nonzero "killed wrapper run exits nonzero" "$WPID_RC"
# The fake logs the abort microseconds after the wrapper's pipe closes; poll
# briefly so the assertion below cannot race the log write.
for _ in $(seq 1 20); do
  if grep -q "aborted: consumer went away" "$SAN/home/fake-dart/log" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
rm -f "$SAN/6b-block" # unblock: the orphaned import finishes the 61 lines
wait_no_sandbox_import
assert_no_fake_task_orphans "$SAN/bin6b"
assert_contains "emitter saw the consumer die" "$(cat "$SAN/home/fake-dart/log")" "aborted: consumer went away"
assert_contains "first note was acked and deleted" "$(cat "$SAN/home/fake-dart/log")" "deleted $KEY6B1"
assert_contains "import fish was provably blocked inside an add before the kill" \
  "$(cat "$SAN/6b-tasklog")" "blocked: add"
assert_contains "blocked add resumed after the marker removal" \
  "$(cat "$SAN/6b-tasklog")" "unblocked: add"
if [[ -e "$SAN/home/fake-dart/objects/$KEY6B2" ]]; then
  echo "ok: mid-stream object kept after consumer death"
else
  fail "mid-stream object was deleted despite consumer death"
fi

rc=0
run_script --dart "$SAN/bin/fakedart" --only "$KEY6B1,$KEY6B2" >/dev/null || rc=$?
assert_rc "re-run after consumer death succeeds" 0 "$rc"
if [[ -e "$SAN/home/fake-dart/objects/$KEY6B2" ]]; then
  fail "emitter kept the object after a successful re-run"
else
  echo "ok: object deleted after successful re-import"
fi
sandbox_export >"$SAN/export.json"
assert_eq "no duplicate descriptions after consumer-death re-run (F2 dedup)" \
  "$(jq '[.[].description] | group_by(.) | map(select(length > 1)) | length' "$SAN/export.json")" 0
assert_eq "multi-line note imported exactly once per good line" \
  "$(jq '[.[] | select(.description == "second good line" or (.description | startswith("fakebulk task")))] | length' "$SAN/export.json")" "$FAKE6B_GOODS"
assert_eq "first acked note imported exactly once" \
  "$(jq '[.[] | select(.description == "fakedart first acked note")] | length' "$SAN/export.json")" 1
