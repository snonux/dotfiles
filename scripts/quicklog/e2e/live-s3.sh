# shellcheck shell=bash
# Live Garage S3 smoke (phases 3–5) — production bucket with --only isolation.
# Sourced by scripts/quicklog/e2e/run — not executed directly.

# --- phase 3: live Garage → taskwarrior happy path ------------------------------------------

say "phase 3: live S3 import via the real wrapper"
if [[ "$TIMER_WAS_ACTIVE" == true ]]; then
  systemctl --user stop quicklog-drain.timer
  echo "quicklog-drain.timer stopped"
fi

# The S3 fixture deliberately repeats the F1/F2 edge cases with fresh
# descriptions so the exact-equality assertions prove the CR strip, the
# trailing-r survival and the leading-dash passthrough over the whole
# S3 → dart → jq → fish → taskwarrior path.
K3A=$(make_key 3)
K3B=$(make_key 4)
K3C=$(make_key 5) # empty note
K3D=$(make_key 6) # note without trailing newline
S3_F3_NOTE=$'s3tag ends in letter r\ns3crlf crlf final letter stays\r\njustoneword\ns3tag -minus literal dash kept\n'
put_note "$K3A" "$S3_F3_NOTE"
put_note "$K3B" 'solo single line note'
put_note "$K3C" ''
put_note "$K3D" 'notrailing newline note'
assert_eq "four fixtures staged" "$(bucket_keys | grep -c '^ql-')" "4"

rc=0
run_script || rc=$?
assert_rc "wrapper exit code" 0 "$rc"
for key in "$K3A" "$K3B" "$K3C" "$K3D"; do
  if bucket_keys | grep -F -x -q "$key"; then
    fail "test key still in bucket after drain: $key"
  else
    echo "ok: drained $key"
  fi
done
assert_eq "tasks in sandbox DB (3 edge lines + 2 single notes)" "$(sandbox_task_count)" "5"
assert_eq "trailing-r description exact over S3 (F1 regression)" \
  "$(count_desc 'ends in letter r')" 1
assert_eq "CRLF description exact over S3 (F1 regression)" \
  "$(count_desc 'crlf final letter stays')" 1
assert_eq "leading-dash description literal over S3" \
  "$(count_desc '-minus literal dash kept')" 1
assert_eq "no description contains a stray carriage return" \
  "$(sandbox_export | jq '[.[] | select(.description | contains("\r"))] | length')" 0
assert_contains "note without trailing newline imported" "$(sandbox_descriptions)" "newline note"
assert_contains "single line note imported" "$(sandbox_descriptions)" "single line note"
assert_eq "no duplicate descriptions after S3 import" \
  "$(sandbox_export | jq '[.[].description] | group_by(.) | map(select(length > 1)) | length')" 0
if [[ ! -d "$SAN/home/Notes/Quicklog" ]] &&
  [[ -z "$(find "$SAN/home" -name 'ql-*' -type f 2>/dev/null)" ]]; then
  echo "ok: no filesystem staging happened"
else
  fail "wrapper staged files into the sandbox"
fi

# --- phase 4: import failure keeps the note; retry imports once -----------------------------

say "phase 4: failed import keeps the object; retry imports exactly once"

K4=$(make_key 7)
put_note "$K4" 'retryme transient import target'
COUNT_BEFORE=$(sandbox_task_count)

mkdir -p "$SAN/blocked"
chmod 555 "$SAN/blocked"
rc=0
run_script --taskdata "$SAN/blocked" >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "ok: wrapper failed with broken taskwarrior (rc=$rc)"
else
  fail "wrapper succeeded despite broken taskwarrior"
fi
assert_contains "failed note kept in bucket" "$(bucket_keys)" "$K4"
assert_eq "no tasks added during failure" "$(sandbox_task_count)" "$COUNT_BEFORE"

rc=0
run_script >/dev/null || rc=$?
assert_rc "retry run succeeds" 0 "$rc"
if bucket_keys | grep -F -x -q "$K4"; then
  fail "retried note still in bucket"
else
  echo "ok: retried note drained"
fi
assert_eq "retried note imported exactly once" \
  "$(sandbox_descriptions | grep -c '^transient import target$')" "1"

# --- phase 4b: crash window — kill mid-import, note kept, re-drain dedups ------------------

say "phase 4b: wrapper kill mid-import keeps the note; re-drain imports no duplicates"

# A multi-line note: good line, malformed line, good line, then bulk
# filler exercising a large note through the crash-window dedup. The kill
# lands at a deterministic moment instead of racing the import (a
# multi-line note imports in a fraction of a second): the import runs
# against a fake `task` that blocks the add of the third line while a
# marker file exists, so when the harness kills the wrapper — the same
# SIGTERM the service's timeout wrapper or a manual `timeout` would
# deliver — the first line has landed, the third add is hung mid-import,
# and ~120 lines are still queued. Unblocking lets the orphaned import
# finish, and the re-drain below must dedup against exactly that state.
K4B=$(make_key 12)
KILLWIN_BODY='killwin first good line\njustoneword\nkillwin third good line\n'
KILLWIN_FILLER=$(seq -f 'killwin bulk task %03.0f' 1 120)
KILLWIN_NOTE=$(printf '%b' "$KILLWIN_BODY"; echo "$KILLWIN_FILLER")
put_note "$K4B" "$KILLWIN_NOTE"
KILLWIN_GOODS=122 # first + third + 120 filler lines

gen_fake_task "$SAN/bin4b" "third good line" "$SAN/4b-block" "$SAN/4b-tasklog"
touch "$SAN/4b-block"
build_wrapper_env "" "" "$SAN/bin4b:$CHILD_PATH"
env "${WRAPPER_ENV[@]}" "$DOTFILES/scripts/quicklog/drain" --only "$K4B" &
WPID=$!
if kill_when_blocked "$WPID" "$SAN/4b-tasklog"; then
  echo "ok: wrapper killed while the import was blocked mid-add"
else
  fail "fake task never blocked — deterministic kill window broken"
fi
wait "$WPID" 2>/dev/null
WPID_RC=$?
assert_rc_nonzero "killed wrapper run exits nonzero" "$WPID_RC"
assert_contains "import fish was provably blocked inside an add before the kill" \
  "$(cat "$SAN/4b-tasklog")" "blocked: add"
rm -f "$SAN/4b-block" # unblock: the orphaned import finishes the queued lines
wait_no_sandbox_import
assert_no_fake_task_orphans "$SAN/bin4b"
wait_no_dart
assert_contains "killed run kept the note in the bucket" "$(bucket_keys)" "$K4B"

rc=0
run_script >/dev/null || rc=$?
assert_rc "re-drain after kill succeeds" 0 "$rc"
if bucket_keys | grep -F -x -q "$K4B"; then
  fail "re-drained note still in bucket"
else
  echo "ok: re-drained note deleted after dedup-import"
fi
sandbox_export >"$SAN/export.json"
assert_eq "no duplicate descriptions after crash-window re-drain (F2 dedup)" \
  "$(jq '[.[].description] | group_by(.) | map(select(length > 1)) | length' "$SAN/export.json")" 0
assert_eq "killwin note imported exactly once per line" \
  "$(jq '[.[] | select(.description == "first good line" or .description == "third good line" or (.description | startswith("bulk task")))] | length' "$SAN/export.json")" "$KILLWIN_GOODS"
assert_eq "malformed killwin line never became a task" \
  "$(jq '[.[] | select(.description == "justoneword")] | length' "$SAN/export.json")" 0

# --- phase 5: --dry-run, --limit, --only and --dest ------------------------------------------

say "phase 5: --dry-run, --limit, --only and --dest"

K5A=$(make_key 8)
K5B=$(make_key 9)
put_note "$K5A" 'limitme first limited note'
put_note "$K5B" 'limitme second limited note'
COUNT_P5=$(sandbox_task_count)

rc=0
run_script --dry-run >/dev/null || rc=$?
assert_rc "dry-run exit code" 0 "$rc"
assert_eq "dry-run deleted nothing" "$(bucket_keys | grep -c '^ql-')" "2"
assert_eq "dry-run imported nothing" "$(sandbox_task_count)" "$COUNT_P5"

rc=0
run_script --force >/dev/null 2>&1 || rc=$?
assert_rc "--force rejected in import mode" 64 "$rc"
assert_eq "--force touched nothing" "$(bucket_keys | grep -c '^ql-')" "2"

rc=0
run_script --limit 1 >/dev/null || rc=$?
assert_rc "limited run exit code" 0 "$rc"
assert_contains "older note imported" "$(sandbox_descriptions)" "first limited note"
assert_not_contains "newer note not imported" "$(sandbox_descriptions)" "second limited note"
assert_eq "only the newer note remains in the bucket" "$(bucket_keys)" "$K5B"

rc=0
run_script >/dev/null || rc=$?
assert_rc "final run drains the rest" 0 "$rc"
assert_contains "newer note imported on next run" "$(sandbox_descriptions)" "second limited note"

say "phase 5b: --only drains only the named keys"

K5C=$(make_key 13)
K5D=$(make_key 14)
put_note "$K5C" 'onlyone targeted by only flag'
put_note "$K5D" 'onlytwo not in the only list'
rc=0
run_script --only "$K5C" >/dev/null || rc=$?
assert_rc "--only run exit code" 0 "$rc"
assert_eq "key in the --only list was drained" "$(count_desc 'targeted by only flag')" 1
assert_contains "key outside --only stays in the bucket" "$(bucket_keys)" "$K5D"

rc=0
run_script >/dev/null || rc=$?
assert_rc "subsequent run drains the remaining key" 0 "$rc"
assert_eq "remaining key imported exactly once" "$(count_desc 'not in the only list')" 1
if bucket_keys | grep -F -x -q "$K5D"; then
  fail "remaining key still in bucket"
else
  echo "ok: remaining key drained"
fi

say "phase 5c: --dest legacy mode smoke test"

K5E=$(make_key 20)
K5F=$(make_key 21)
mkdir -p "$SAN/dest"
put_note "$K5E" 'destmode first legacy note'
put_note "$K5F" 'destmode second legacy note'
rc=0
run_script --dest "$SAN/dest" >/dev/null || rc=$?
assert_rc "--dest run exit code" 0 "$rc"
assert_eq "first legacy file landed with exact content" \
  "$(cat "$SAN/dest/$K5E")" 'destmode first legacy note'
assert_eq "second legacy file landed with exact content" \
  "$(cat "$SAN/dest/$K5F")" 'destmode second legacy note'
remaining_after_dest=$(bucket_keys)
for key in "$K5E" "$K5F"; do
  if [[ "$remaining_after_dest" == *"$key"* ]]; then
    fail "--dest left object behind: $key"
  else
    echo "ok: --dest deleted remote object $key"
  fi
done

say "phase 5d: stranded staging-dir preflight reports and proceeds"

# F3: notes staged into ~/Notes/Quicklog by the retired flow are stranded
# (nothing scans that directory anymore). The import preflight must warn
# about them, and the import must still proceed.
mkdir -p "$SAN/home/Notes/Quicklog"
printf 'stranded staged by the old flow\n' >"$SAN/home/Notes/Quicklog/ql-e2e-stranded.md"
K5G=$(make_key 22)
put_note "$K5G" 'strandchk import proceeds anyway'
rc=0
run_script >"$SAN/strand.out" 2>&1 || rc=$?
assert_rc "import proceeds despite stranded files" 0 "$rc"
assert_contains "stranded preflight warns" "$(cat "$SAN/strand.out")" "stranded"
assert_contains "stranded preflight names the file" "$(cat "$SAN/strand.out")" "ql-e2e-stranded.md"
# The wrapper's hint contains a literal ~/Notes on purpose (human-facing text)
# shellcheck disable=SC2088
assert_contains "stranded preflight hints at ~/Notes" "$(cat "$SAN/strand.out")" "~/Notes"
assert_eq "stranded file was not imported by the drain" "$(count_desc 'staged by the old flow')" 0
if [[ -e "$SAN/home/Notes/Quicklog/ql-e2e-stranded.md" ]]; then
  echo "ok: stranded file left in place for the operator"
else
  fail "stranded file was consumed or moved"
fi
assert_eq "import still drained its own key" "$(count_desc 'import proceeds anyway')" 1
rm -rf "$SAN/home/Notes/Quicklog"
