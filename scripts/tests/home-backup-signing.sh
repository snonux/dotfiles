#!/usr/bin/env bash
# Actual local rsync checks; never contact a backup host or use real keys.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$SCRIPT_DIR/../home-backup"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
mkdir -p "$TEST_ROOT/home/git/conf/packages/buildvm" \
    "$TEST_ROOT/home/.local/share/f3s-package-signing/gnupg" \
    "$TEST_ROOT/home/custom-xdg/f3s-package-signing/gnupg" \
    "$TEST_ROOT/home/Documents" "$TEST_ROOT/backup"
printf 'ordinary document\n' > "$TEST_ROOT/home/Documents/keep.txt"
printf 'legacy test fixture\n' > \
    "$TEST_ROOT/home/git/conf/packages/buildvm/custom-pkg.sec"
printf 'disk test fixture\n' > \
    "$TEST_ROOT/home/git/conf/packages/buildvm/openbsd-build.qcow2"
printf 'new private test fixture\n' > \
    "$TEST_ROOT/home/.local/share/f3s-package-signing/gnupg/key"
printf 'custom private test fixture\n' > \
    "$TEST_ROOT/home/custom-xdg/f3s-package-signing/gnupg/key"
HOME="$TEST_ROOT/home" BACKUP_DEST="$TEST_ROOT/backup" \
    "$BACKUP" >/dev/null
test -f "$TEST_ROOT/backup/Documents/keep.txt"
test ! -e "$TEST_ROOT/backup/git"
test ! -e "$TEST_ROOT/backup/.local/share/f3s-package-signing"
test ! -e "$TEST_ROOT/backup/custom-xdg/f3s-package-signing"

# --delete-excluded must not silently delete an old raw backup. Retention
# here is deliberate: actual remote cleanup requires separate live approval.
mkdir -p "$TEST_ROOT/backup/.local/share/f3s-package-signing/gnupg" \
    "$TEST_ROOT/backup/custom-xdg/f3s-package-signing"
printf 'existing backup fixture\n' > \
    "$TEST_ROOT/backup/.local/share/f3s-package-signing/gnupg/retained"
printf 'existing custom fixture\n' > \
    "$TEST_ROOT/backup/custom-xdg/f3s-package-signing/retained"
HOME="$TEST_ROOT/home" BACKUP_DEST="$TEST_ROOT/backup" \
    "$BACKUP" >/dev/null
test -f "$TEST_ROOT/backup/.local/share/f3s-package-signing/gnupg/retained"
test -f "$TEST_ROOT/backup/custom-xdg/f3s-package-signing/retained"
test ! -e "$TEST_ROOT/backup/.local/share/f3s-package-signing/gnupg/key"
test ! -e "$TEST_ROOT/backup/custom-xdg/f3s-package-signing/gnupg/key"
printf 'home-backup signing-custody test: ok\n'
