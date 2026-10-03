# shellcheck shell=bash
# Shared helpers for the Quicklog drain e2e harness (scripts/quicklog/e2e).
# Sourced by run — not executed directly. Sources scripts/lib/e2e-assert.sh.

: "${PROGRAM:=${0##*/}}"
: "${FAILURES:=0}"
: "${SAN:=}"
: "${TIMER_WAS_ACTIVE:=false}"
: "${REAL_HOME:=$HOME}"
: "${CREDS:=${QUICKLOG_CREDS:-$HOME/.config/garage/quicklog.env}}"
: "${REPO:=${QUICKLOG_REPO:-$HOME/git/quicklog}}"
: "${DART:=${QUICKLOG_DART:-$HOME/flutter/bin/dart}}"
: "${REAL_TASK:=/usr/bin/task}"
: "${CHILD_PATH:=/usr/local/bin:/usr/bin:/bin}"

_E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES:-}" ]]; then
  if [[ -n "${QUICKLOG_E2E_DOTFILES:-}" ]]; then
    DOTFILES="$QUICKLOG_E2E_DOTFILES"
  else
    DOTFILES="$(cd "$_E2E_DIR/../../.." && pwd)"
  fi
fi
if [[ ! -r "$DOTFILES/fish/conf.d/quicklog.fish" ]]; then
  echo "$PROGRAM: $DOTFILES has no fish/conf.d/quicklog.fish — set QUICKLOG_E2E_DOTFILES to the dotfiles repo" >&2
  exit 1
fi

# shellcheck source=scripts/lib/e2e-assert.sh
source "$_E2E_DIR/../../lib/e2e-assert.sh"

ql_e2e::load_creds() {
  # Live-S3 only: load credentials once, exactly like the production wrapper.
  # They stay in this process and are passed explicitly (never printed) to the
  # Dart tools. protocol-fake must not call this — it never talks to Garage.
  # shellcheck disable=SC1090
  source "$CREDS"
  S3_ENV_ARGS=(
    "GARAGE_ENDPOINT=${GARAGE_ENDPOINT:-}"
    "GARAGE_REGION=${GARAGE_REGION:-}"
    "GARAGE_BUCKET=${GARAGE_BUCKET:-}"
    "GARAGE_ACCESS_KEY_ID=${GARAGE_ACCESS_KEY_ID:-}"
    "GARAGE_SECRET_ACCESS_KEY=${GARAGE_SECRET_ACCESS_KEY:-}"
  )
}

# Dummy Garage env for the drain wrapper on the protocol-fake path (drain
# always sources QUICKLOG_CREDS even when QUICKLOG_DART is a fake emitter).
ql_e2e::write_dummy_creds() { # ql_e2e::write_dummy_creds PATH
  cat >"$1" <<'EOF'
GARAGE_ENDPOINT=http://127.0.0.1:9
GARAGE_REGION=garage
GARAGE_BUCKET=quicklog-e2e-dummy
GARAGE_ACCESS_KEY_ID=dummy
GARAGE_SECRET_ACCESS_KEY=dummy
EOF
}

# Cross-phase wipe: run orchestration calls this between phases so counts stay
# exact. Parser-local must not wipe the sandbox for later phases.
ql_e2e::reset_sandbox_taskdata() {
  rm -rf "$SAN/taskdata"
  mkdir -p "$SAN/taskdata"
}

# --- live S3 helpers --------------------------------------------------------

s3() { # s3 <bin/quicklog_drain.dart args...>
  env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" "${S3_ENV_ARGS[@]}" \
    "$DART" run bin/quicklog_drain.dart "$@"
}

put_note() { # put_note KEY CONTENT — stage a fixture object in the bucket
  TEST_KEYS+=("$1")
  printf '%s' "$2" |
    env -C "$REPO" -i HOME="$REAL_HOME" PATH="$CHILD_PATH" "${S3_ENV_ARGS[@]}" \
      "$DART" run tool/put_note.dart "$1"
}

bucket_keys() { # ql-* keys currently in the bucket
  s3 --keys 2>/dev/null
}

# --- sandbox taskwarrior helpers ---------------------------------------------

tw() { # tw <task args...> — task against the sandbox DB
  env -i HOME="$SAN/home" TASKDATA="$SAN/taskdata" PATH="$CHILD_PATH" \
    "$REAL_TASK" rc.verbose=nothing "$@"
}

sandbox_task_count() {
  tw status:pending count 2>/dev/null | tail -1
}

sandbox_export() { # exports pending tasks as JSON to stdout
  tw rc.json.array=on status:pending export 2>/dev/null
}

sandbox_descriptions() {
  sandbox_export | jq -r '.[].description' | sort
}

count_desc() { # count_desc DESC — number of pending tasks with this exact description
  sandbox_export | jq --arg d "$1" '[.[] | select(.description == $d)] | length'
}

# --- fingerprints of the user's real data ------------------------------------
#
# The real taskwarrior DB is checked by content, never by invoking the real
# task binary: ~/.taskrc configures S3 sync and the DB is 80 MB+ — launching
# real taskwarrior from a test is neither cheap nor side-effect-free. The
# fingerprints hash the file content (immune to the mtime granularity races
# that made the old size+mtime check flaky) and use find -L because ~/.task
# is a symlink that plain `find` never descends into (the old file count was
# a constant zero for exactly that reason).

real_db_fingerprint() {
  local db="$REAL_HOME/.task/taskchampion.sqlite3"
  if [[ ! -e "$db" ]]; then
    echo "no-task-db"
    return 0
  fi
  local count main_sha wal_sha
  count=$(find -L "$REAL_HOME/.task" -maxdepth 1 -type f 2>/dev/null | wc -l)
  main_sha=$(sha256sum "$db" | cut -d' ' -f1)
  if [[ -e "$db-wal" ]]; then
    wal_sha=$(sha256sum "$db-wal" | cut -d' ' -f1)
  else
    wal_sha="no-wal"
  fi
  echo "$count $main_sha $wal_sha"
}

# Cheap semantic fingerprint via a read-only sqlite query (no taskwarrior
# launch, no sync, no hooks): task count and content size. immutable=1 is
# required — a plain mode=ro WAL reader *creates* -shm/-wal journal files
# next to the real DB (observed live), which would both dirty the user's
# ~/.task and break the content fingerprint above.
real_db_semantics() {
  local db="$REAL_HOME/.task/taskchampion.sqlite3"
  if [[ ! -e "$db" ]]; then
    echo "no-task-db"
    return 0
  fi
  sqlite3 "file:$db?mode=ro&immutable=1" \
    'SELECT count(*), coalesce(sum(length(data)),0) FROM tasks' 2>/dev/null \
    || echo "sqlite-unreadable"
}

real_notes_fingerprint() {
  find -L "$REAL_HOME/Notes" -maxdepth 1 -name 'ql-*' -type f 2>/dev/null | sort
  # ~/Notes is a symlink: find -L or the staging dir is never reached
  find -L "$REAL_HOME/Notes/Quicklog" -maxdepth 1 -printf '%P %s %T@\n' 2>/dev/null |
    sha256sum | cut -d' ' -f1
}

real_due_stamp_fingerprint() {
  stat -c '%Y' "$REAL_HOME/.taskwarrior_due.last" 2>/dev/null || echo "no-stamp"
}

# --- fixtures ------------------------------------------------------------------

# One note exercising the line-format edge cases, imported straight into the
# headless fish in phase 2. Expected tasks:
#   1. home/groceries "buy milk ✓ ünïcode", due in 2 days
#   2. project/tag1+tag2 "ship the thing" (no due)
#   3. tagonly "do stuff" (single tag, no project)
#   4. foo/bar "weird tags" (Foo→project, empty tag token dropped)
#   5. tagonly "+urgent fix it" (+ token kept in the description by `--`)
#   6. tagonly "do normalized stuff" (doubled spaces collapse)
#   7. tagonly "fix the parser" (trailing 'r' must survive the CR strip)
#   8. crlftag "keep final letter" (literal CRLF: CR stripped, no r chopped)
#   9. tagonly "-dash leading minus stays" (leading-dash description literal)
#  10. longtag "x"×1000 (very long description)
# Malformed lines (blank, whitespace-only, bare word, bare due number, due
# offset outside 0..10000) are permanently skipped — 10 tasks total.
# Used by parser-local.sh (sourced after this file).
# shellcheck disable=SC2034
FIXTURE_GOOD=10
LONG_DESC=$(printf 'x%.0s' $(seq 1000))
# shellcheck disable=SC2034
FIXTURE_NOTE=$'2 Home,groceries buy milk ✓ ünïcode\nProject,tag1,tag2 ship the thing\n\ntagonly do stuff\n   \njustoneword\n3\nFoo,,bar weird tags\ntagonly +urgent fix it\ntagonly do  normalized   stuff\ntagonly fix the parser\ncrlftag keep final letter\r\n99999 tagonly due way out of range\ntagonly -dash leading minus stays\nlongtag '$LONG_DESC$'\n'

make_key() { # make_key OFFSET_SECONDS — valid ql-YYMMDD-HHMMSS.md key
  printf 'ql-%s.md' "$(date -u -d "+$1 seconds" +%y%m%d-%H%M%S)"
}

# --- cleanup ---------------------------------------------------------------------

cleanup() {
  local rc=$?
  echo
  say "cleanup"
  local key remaining
  if [[ -n "${S3_ENV_ARGS+x}" && ${#TEST_KEYS[@]} -gt 0 ]]; then
    remaining=$(bucket_keys 2>/dev/null)
    for key in "${TEST_KEYS[@]}"; do
      if [[ "$remaining" == *"$key"* ]]; then
        if s3 --delete "$key" >/dev/null 2>&1; then
          echo "deleted leftover $key"
        else
          echo "could not delete leftover $key" >&2
        fi
      fi
    done
  fi
  rm -f /tmp/ql-e2e-*.md
  if [[ -n "$SAN" && -d "$SAN" ]]; then
    rm -rf "$SAN"
    echo "removed sandbox $SAN"
  fi
  if [[ "$TIMER_WAS_ACTIVE" == true ]]; then
    systemctl --user start quicklog-drain.timer
    if systemctl --user is-active --quiet quicklog-drain.timer; then
      echo "restored quicklog-drain.timer (active)"
    else
      echo "$PROGRAM: FAILED to restore quicklog-drain.timer" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi
  echo
  if ((FAILURES == 0 && rc == 0)); then
    echo "E2E RESULT: ALL PHASES PASSED"
  else
    echo "E2E RESULT: $FAILURES assertion(s) failed (script rc=$rc)"
  fi
  exit $((FAILURES > 0 ? 1 : rc))
}

# --- sandbox ------------------------------------------------------------------

ql_e2e::build_sandbox() {
  say "phase 1: build sandbox"

  SAN=$(mktemp -d /tmp/ql-e2e.XXXXXX)
  mkdir -p "$SAN/home" "$SAN/taskdata" "$SAN/conf.d" "$SAN/xdg" "$SAN/wt" "$SAN/bin"
  echo "data.location=$SAN/taskdata" >"$SAN/home/.taskrc"
  cp "$DOTFILES/fish/conf.d/taskwarrior.fish" "$SAN/conf.d/"
  cp "$DOTFILES/fish/conf.d/quicklog.fish" "$SAN/conf.d/"
  echo "sandbox at $SAN"
}

ql_e2e::require_tools() { # ql_e2e::require_tools TOOL...
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || {
      echo "$PROGRAM: missing tool: $tool" >&2
      exit 1
    }
  done
}


# The real wrapper with every path knob pointed at the sandbox. Every drain
# passes --only with the harness's own staged keys (see header: the phone-note
# mid-run hazard). Options:
#   --taskdata DIR  override the sandbox TASKDATA (broken-DB scenarios)
#   --dart PATH     override the dart binary (fake-emitter scenarios)
#   --only CSV      override the --only key list (default: all staged keys)
# The third positional arg of build_wrapper_env sets QUICKLOG_FISH_PATH
# (fake-`task` kill-test scenarios); run_script itself never sets it.
build_wrapper_env() { # build_wrapper_env [TASKDATA] [DART] [FISH_PATH]
  WRAPPER_ENV=(
    HOME="$SAN/home"
    TASKDATA="${1:-$SAN/taskdata}"
    XDG_RUNTIME_DIR="$SAN/xdg"
    QUICKLOG_CREDS="$CREDS"
    QUICKLOG_REPO="$REPO"
    QUICKLOG_DART="${2:-$DART}"
    QUICKLOG_FISH_CONF_DIR="$SAN/conf.d"
    PUB_CACHE="$REAL_HOME/.pub-cache"
  )
  if [[ -n "${3:-}" ]]; then
    WRAPPER_ENV+=("QUICKLOG_FISH_PATH=$3")
  fi
}

test_keys_csv() { # comma-separated list of all keys this run has staged
  local IFS=,
  printf '%s' "${TEST_KEYS[*]}"
}

run_script() { # run_script [--taskdata DIR] [--dart PATH] [--only CSV] <wrapper args...>
  local taskdata="" dartbin="" only_csv=""
  while [[ "${1:-}" == --taskdata || "${1:-}" == --dart || "${1:-}" == --only ]]; do
    case "$1" in
      --taskdata) taskdata="$2" ;;
      --dart) dartbin="$2" ;;
      --only) only_csv="$2" ;;
    esac
    shift 2
  done
  build_wrapper_env "$taskdata" "$dartbin"
  only_csv="${only_csv:-$(test_keys_csv)}"
  if [[ -z "$only_csv" ]]; then
    # Empty --only is a wrapper usage error (exit 64). Refuse here so
    # protocol-fake / callers get a clear harness fault instead.
    echo "$PROGRAM: run_script: empty --only (pass --only KEYS or put_note first)" >&2
    return 64
  fi
  env "${WRAPPER_ENV[@]}" "$DOTFILES/scripts/quicklog/drain" --only "$only_csv" "$@"
}

# Headless fish against the sandbox (production parity: QUICKLOG_HEADLESS).
# The fish command is single-quoted on purpose: $QUICKLOG_FISH_CONF_DIR is
# expanded by fish from its own environment, not by this shell.
run_fish() { # run_fish <fish command>
  # shellcheck disable=SC2016
  env -i \
    HOME="$SAN/home" \
    TASKDATA="$SAN/taskdata" \
    QUICKLOG_HEADLESS=1 \
    QUICKLOG_FISH_CONF_DIR="$SAN/conf.d" \
    PATH="$CHILD_PATH" \
    fish --no-config -c '
      source "$QUICKLOG_FISH_CONF_DIR/taskwarrior.fish"
      source "$QUICKLOG_FISH_CONF_DIR/quicklog.fish"
      '"$1"'
    '
}

# Is a headless import fish still writing to the sandbox DB? Matched via the
# cmdline plus the sandbox TASKDATA in its environment, so other users of the
# same functions (an interactive `ti`) are never mistaken for ours.
sandbox_import_running() {
  local pid
  for pid in $(pgrep -f 'taskwarrior::quicklog_import_content' 2>/dev/null); do
    if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null |
      grep -q "^TASKDATA=$SAN/taskdata$"; then
      return 0
    fi
  done
  return 1
}

wait_no_sandbox_import() {
  local _
  for _ in $(seq 1 90); do
    sandbox_import_running || return 0
    sleep 1
  done
  fail "sandbox import fish still running after 90s"
  return 1
}

wait_no_dart() { # the real drain tool EOF-aborts on its own once the wrapper dies
  local _
  for _ in $(seq 1 30); do
    pgrep -f 'bin/quicklog_drain.dart' >/dev/null 2>&1 || return 0
    sleep 1
  done
  echo "note: dart drain process still lingering; continuing" >&2
}

# Fake `task` binary for the deterministic kill tests (phases 4b and 6b):
# passthrough to the real taskwarrior, except an invocation whose arguments
# contain SENTINEL blocks for as long as MARKER exists (logging to LOG
# first). The harness waits for the "blocked" log line — proof the import
# fish is inside that very add — kills the wrapper, removes the marker, and
# the orphaned import then completes against the real binary.
gen_fake_task() { # gen_fake_task DIR SENTINEL MARKER LOG
  local dir="$1" sentinel="$2" marker="$3" log="$4"
  mkdir -p "$dir"
  cat >"$dir/task" <<EOF
#!/bin/bash
# Generated by quicklog e2e: blocks the add containing the sentinel
# description while the marker file exists, then execs the real binary.
if [[ "\$*" == *"$sentinel"* && -e "$marker" ]]; then
  printf 'blocked: %s\n' "\$*" >>"$log"
  while [[ -e "$marker" ]]; do
    sleep 0.1
  done
  printf 'unblocked: %s\n' "\$*" >>"$log"
fi
exec $REAL_TASK "\$@"
EOF
  chmod +x "$dir/task"
}

# Wait until the fake `task` logs that it blocked the sentinel add, then
# SIGTERM the wrapper: the import is provably mid-note at kill time. Returns
# 1 (after killing anyway) if the block never happened — a hard FAIL, not a
# silent fallback to a racy kill.
kill_when_blocked() { # kill_when_blocked WRAPPER_PID LOG
  local _
  for _ in $(seq 1 240); do
    if grep -q '^blocked:' "$2" 2>/dev/null; then
      kill -TERM "$1" 2>/dev/null || true
      return 0
    fi
    sleep 0.25
  done
  kill -TERM "$1" 2>/dev/null || true
  return 1
}

# After the marker removal and wait_no_sandbox_import, no process of the
# fake `task` may survive (the orphaned import must have drained past it).
assert_no_fake_task_orphans() { # assert_no_fake_task_orphans DIR
  if pgrep -f "$1/task" >/dev/null 2>&1; then
    fail "orphan fake task process left behind ($1/task)"
  else
    echo "ok: no orphan fake task processes left behind"
  fi
}
