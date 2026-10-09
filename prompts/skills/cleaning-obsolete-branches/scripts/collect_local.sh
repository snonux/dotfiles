#!/usr/bin/env bash
# Read-only: for every git repo directly under the given directories, list
# non-default local branches and remote-tracking branches with tip date and
# ahead/behind relative to the default branch. No fetch, no writes.
# Output TSV: repo-path base kind(local|remote) branch date ahead behind upstream-track
set -u

(( $# )) || { echo "usage: $0 <dir-with-repos>..." >&2; exit 2; }

# Prefer a local main/master; fall back to origin's HEAD, then the checked-out branch.
default_branch() {
    local d
    for d in main master; do
        git show-ref --verify --quiet "refs/heads/$d" && { echo "$d"; return; }
    done
    d=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "$d"; return; }
    git symbolic-ref --quiet --short HEAD 2>/dev/null
}

scan_repo() {
    local repo=$1 base ref kind name date ahead behind track
    cd "$repo" 2>/dev/null || return
    git rev-parse --git-dir >/dev/null 2>&1 || return
    base=$(default_branch)
    [[ -z "$base" ]] && { echo "no default branch: $repo" >&2; return; }
    git for-each-ref --format='%(refname)%09%(committerdate:short)%09%(upstream:track)' \
        refs/heads refs/remotes | while IFS=$'\t' read -r ref date track; do
        case "$ref" in
            refs/heads/*) kind=local; name=${ref#refs/heads/} ;;
            *) kind=remote; name=${ref#refs/remotes/} ;;
        esac
        # Skip the default branch itself, its remote copies, and symbolic HEADs.
        # "$base" == */"$name" covers repos without main/master, where base is
        # origin/<x> and the local <x> is the only real branch.
        [[ "$name" == "$base" || "$name" == */"$base" || "$base" == */"$name" ]] && continue
        [[ "$name" == */HEAD || "$name" == */main || "$name" == */master ]] && continue
        read -r behind ahead < <(git rev-list --left-right --count "$base...$ref" 2>/dev/null)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$repo" "$base" "$kind" "$name" "$date" "${ahead:-?}" "${behind:-?}" "$track"
    done
}

for parent in "$@"; do
    parent=${parent%/}
    for dir in "$parent"/*/; do
        dir=${dir%/}
        # The gitsyncer work dir lives inside ~/git but is passed as its own argument.
        [[ "$dir" == */gitsyncer-workdir ]] && continue
        [[ -e "$dir/.git" || -f "$dir/HEAD" ]] && (scan_repo "$dir")
    done
done
