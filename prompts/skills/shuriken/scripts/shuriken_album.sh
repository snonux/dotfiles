#!/usr/bin/env bash
#
# Generate a shuriken photo album from a directory of photos and publish it to
# the home web servers. Lean build: no tarball, no stats site, no per-photo
# details pages.
#
# Usage: shuriken_album.sh [--clean|--keep] [--no-sync] INDIR ALBUM_NAME [DIST_DIR]

set -euo pipefail

# Overridable through the environment, e.g. to exercise a source checkout:
#   SHURIKEN=~/git/shuriken.sh/bin/shuriken
#   SHURIKEN_CONF=~/git/shuriken.sh/src/shuriken.default.conf
#   SHURIKEN_TEMPLATE=~/git/shuriken.sh/share/templates/default
readonly SHURIKEN="${SHURIKEN:-shuriken}"
readonly SHURIKEN_CONF="${SHURIKEN_CONF:-/etc/default/shuriken}"
readonly SHURIKEN_TEMPLATE="${SHURIKEN_TEMPLATE:-}"

# pi0 goes first: it is the source of truth, and pi1's hourly cron mirrors pi0's
# docroot with --delete, so an album that exists only on pi1 would be removed.
readonly -a SYNC_HOSTS=(pi0.lan pi1.lan)
readonly REMOTE_BASE=/var/www/html/fotos
# The docroot is root-owned on both NetBSD hosts, so the receiving rsync runs
# under doas. doas needs the absolute path there (bare names are not found).
readonly REMOTE_RSYNC='doas /usr/pkg/bin/rsync'

usage() {
    cat <<'USAGE' >&2
Usage: shuriken_album.sh [--clean|--keep] [--no-sync] INDIR ALBUM_NAME [DIST_DIR]

  INDIR       directory holding the source photos
  ALBUM_NAME  album title and remote folder name under /var/www/html/fotos
  DIST_DIR    output directory (default: dist next to INDIR)

  --clean     wipe a non-empty DIST_DIR first (shuriken --clean)
  --keep      generate into a non-empty DIST_DIR (re-run of the SAME album)
  --no-sync   generate only, do not publish
USAGE
    exit 2
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

# Common shuriken arguments shared by --clean and --generate.
shuriken_args() {
    local -r indir="$1"; shift
    local -r dist="$1"; shift

    printf '%s\0' --config "$SHURIKEN_CONF" --incoming "$indir" --dist "$dist"
    if [ -n "$SHURIKEN_TEMPLATE" ]; then
        printf '%s\0' --template "$SHURIKEN_TEMPLATE"
    fi
}

check_inputs() {
    local -r indir="$1"; shift
    local -r name="$1"; shift

    [ -d "$indir" ] || die "INDIR is not a directory: $indir"
    [ -n "$(find "$indir" -maxdepth 1 -type f -print -quit)" ] \
        || die "INDIR contains no files: $indir"
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || die "ALBUM_NAME may only contain letters, digits, '.', '_' and '-': $name"
    [ -f "$SHURIKEN_CONF" ] || die "shuriken config not found: $SHURIKEN_CONF"
}

# A DIST_DIR left over from another album must not leak into this one, so a
# non-empty one needs an explicit decision.
prepare_dist() {
    local -r mode="$1"; shift
    local -r indir="$1"; shift
    local -r dist="$1"; shift
    local -a args

    if [ ! -d "$dist" ] || [ -z "$(find "$dist" -mindepth 1 -print -quit)" ]; then
        return 0
    fi

    case "$mode" in
        clean)
            mapfile -d '' args < <(shuriken_args "$indir" "$dist")
            "$SHURIKEN" --clean "${args[@]}"
            ;;
        keep)
            ;;
        *)
            die "DIST_DIR is not empty: $dist (pass --clean to wipe it, or --keep to re-run the same album)"
            ;;
    esac
}

generate() {
    local -r indir="$1"; shift
    local -r name="$1"; shift
    local -r dist="$1"; shift
    local -a args

    mapfile -d '' args < <(shuriken_args "$indir" "$dist")
    "$SHURIKEN" --generate "${args[@]}" \
        --title "$name" \
        --image-jobs "$(nproc)" \
        --no-tarball --no-stats --no-details \
        --quiet

    [ -f "$dist/index.html" ] || die "generation produced no $dist/index.html"
}

# Push DIST_DIR to every host and prove the copy: same file count as the local
# album and the splash page answering over HTTP.
sync_album() {
    local -r name="$1"; shift
    local -r dist="$1"; shift
    local -r remote_dir="$REMOTE_BASE/$name"
    local host local_count remote_count http_code

    local_count=$(find "$dist" -type f | wc -l)

    for host in "${SYNC_HOSTS[@]}"; do
        printf 'Syncing to %s:%s\n' "$host" "$remote_dir"
        rsync -a --delete --rsync-path="$REMOTE_RSYNC" "$dist/" "$host:$remote_dir/"

        # $remote_dir is expanded locally on purpose; check_inputs restricts
        # ALBUM_NAME to shell-safe characters.
        # shellcheck disable=SC2029
        remote_count=$(ssh -o BatchMode=yes "$host" "find '$remote_dir' -type f | wc -l")
        remote_count="${remote_count//[[:space:]]/}"
        [ "$remote_count" = "$local_count" ] \
            || die "$host has $remote_count files, expected $local_count"

        http_code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' \
            "http://$host/fotos/$name/index.html")
        [ "$http_code" = 200 ] || die "$host answered HTTP $http_code for the album"
        printf 'OK %s: %s files, http://%s/fotos/%s/\n' "$host" "$remote_count" "$host" "$name"
    done
}

main() {
    local mode=refuse
    local do_sync=yes

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --clean) mode=clean; shift ;;
            --keep) mode=keep; shift ;;
            --no-sync) do_sync=no; shift ;;
            -h|--help) usage ;;
            --) shift; break ;;
            -*) die "unknown option: $1" ;;
            *) break ;;
        esac
    done

    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage

    local indir name dist
    indir=$(realpath "$1")
    name="$2"
    dist=$(realpath -m "${3:-$(dirname "$indir")/dist}")

    check_inputs "$indir" "$name"
    prepare_dist "$mode" "$indir" "$dist"
    generate "$indir" "$name" "$dist"

    if [ "$do_sync" = yes ]; then
        sync_album "$name" "$dist"
    fi
}

main "$@"
