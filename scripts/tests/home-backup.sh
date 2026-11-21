#!/usr/bin/env bash
# Option handling, log output and the exact rsync command line of
# scripts/home-backup (pg4: pinned before main was split). rsync is a fake
# that records its argv, so nothing is copied and no host is contacted.
# tests/home-backup-signing.sh covers the real local rsync behaviour.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r BACKUP="$SCRIPT_DIR/../home-backup"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    printf 'home-backup test: %s\n' "$*" >&2
    exit 1
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"
# Fake rsync: one argument per line in rsync.argv; RSYNC_RC sets its status.
cat >"$TEST_ROOT/bin/rsync" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$RSYNC_ARGV"
exit "${RSYNC_RC:-0}"
EOF
chmod +x "$TEST_ROOT/bin/rsync"
export RSYNC_ARGV="$TEST_ROOT/rsync.argv"

# run_backup ARGS... — run home-backup with the fake rsync and a scratch
# HOME; sets rc, leaves stdout/stderr in out/err. BACKUP_DEST is unset
# unless the caller exports it.
run_backup() {
    rm -f "$RSYNC_ARGV"
    rc=0
    HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" \
        "$BACKUP" "$@" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || rc=$?
}

# want_argv DRY DEST — the exact rsync argv for a run (DRY is yes|no).
want_argv() {
    local -r dry="$1" dest="$2"
    printf '%s\n' -aHAX --numeric-ids --partial --progress --delete \
        --delete-excluded --human-readable
    [[ "$dry" == yes ]] && printf '%s\n' --dry-run
    printf '%s\n' -e ssh '--filter=P **/f3s-package-signing/***' \
        --exclude=f3s-package-signing/ --exclude=/git/ --exclude=/syncthing/ \
        --exclude=/Pictures/ --exclude=/Music/ --exclude=/.gradle/ \
        --exclude=/.thunderbird/ --exclude=/.cache/ \
        --exclude=/.local/share/Trash/ --exclude=/.local/share/baloo/ \
        --exclude=/.local/share/containers/ \
        --exclude=/.local/share/gnome-boxes/ --exclude=/.npm/ --exclude=/go/ \
        --exclude=/.cargo/ --exclude=/.bun/ --exclude=/.android/ \
        --exclude=node_modules/ --exclude=.cache/ '--exclude=*.tmp' \
        '--exclude=/.var/app/*/cache/' --exclude=/.gvfs/ --exclude=/.dbus/ \
        "$TEST_ROOT/home/" "$dest"
}

unset BACKUP_DEST
inv_dest=$(bash -c 'source "$1"; printf %s "${F3S_SSH_USER}@${F3S_HOME_BACKUP_HOST}:/data/enc/earth-backup"' \
    bash "$SCRIPT_DIR/../lib/f3s-hosts.sh") || fail "cannot read inventory"

# Default destination from the inventory, live mode.
run_backup
((rc == 0)) || fail "default run exited $rc: $(cat "$TEST_ROOT/err")"
[[ "$(cat "$RSYNC_ARGV")" == "$(want_argv no "$inv_dest")" ]] \
    || fail "default rsync argv changed: $(cat "$RSYNC_ARGV")"
[[ "$(cat "$TEST_ROOT/out")" == "Source:      $TEST_ROOT/home/
Destination: $inv_dest


Backup complete." ]] || fail "default output changed: $(cat "$TEST_ROOT/out")"
[[ ! -s "$TEST_ROOT/err" ]] || fail "default run wrote stderr: $(cat "$TEST_ROOT/err")"

# -n and -d (which beats BACKUP_DEST).
BACKUP_DEST='env@host:/env' run_backup -n -d 'flag@host:/flag'
((rc == 0)) || fail "-n -d run exited $rc"
[[ "$(cat "$RSYNC_ARGV")" == "$(want_argv yes 'flag@host:/flag')" ]] \
    || fail "-n -d rsync argv changed: $(cat "$RSYNC_ARGV")"
[[ "$(cat "$TEST_ROOT/out")" == "Source:      $TEST_ROOT/home/
Destination: flag@host:/flag
Mode:        DRY RUN (no data transferred)


Backup complete." ]] || fail "-n output changed: $(cat "$TEST_ROOT/out")"
BACKUP_DEST='env@host:/env' run_backup
[[ "$(tail -n 1 "$RSYNC_ARGV")" == 'env@host:/env' ]] \
    || fail "BACKUP_DEST ignored: $(tail -n 1 "$RSYNC_ARGV")"

# A failed rsync stops the run (set -e) before 'Backup complete.'.
RSYNC_RC=23 run_backup
((rc == 23)) || fail "failed rsync: want rc 23, got $rc"
if grep -Fq 'Backup complete.' "$TEST_ROOT/out"; then
    fail "failed rsync still printed 'Backup complete.'"
fi

# Refusals: none of them runs rsync.
# expect_refusal WANT_RC WANT_ERR ARGS... — exact status and stderr.
expect_refusal() {
    local -r want_rc="$1" want_err="$2"
    shift 2
    run_backup "$@"
    ((rc == want_rc)) || fail "'$*': want rc $want_rc, got $rc"
    [[ "$(cat "$TEST_ROOT/err")" == "$want_err" ]] \
        || fail "'$*': stderr changed: $(cat "$TEST_ROOT/err")"
    [[ ! -e "$RSYNC_ARGV" ]] || fail "'$*': rsync ran"
}
expect_refusal 2 'Option -d requires an argument.' -d
expect_refusal 2 'Unknown option: -x' -x
expect_refusal 0 '' -h
grep -Fxq 'Usage: home-backup [-n] [-d DEST]' "$TEST_ROOT/out" \
    || fail "-h: usage missing: $(cat "$TEST_ROOT/out")"
expect_refusal 1 'No backup destination set.
Set BACKUP_DEST, pass -d user@host:/path, or edit DEST in home-backup.' -d ''
expect_refusal 1 'No backup destination set.
Set BACKUP_DEST, pass -d user@host:/path, or edit DEST in home-backup.' \
    -d CHANGEME_dest

printf 'home-backup test: ok\n'
