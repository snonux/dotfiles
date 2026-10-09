#!/usr/bin/env python3
"""Classify the collected branches into delete candidates and review-only branches.

  make_candidates.py <datadir> <out.txt>

Reads gh.tsv, fj.tsv, prs.tsv and local.tsv from <datadir> (see collect_all.sh).
Only reads local repos (git cherry / rev-parse); never changes anything."""
import collections
import csv
import datetime
import os
import sys

from forge import HOME, run

# Publishing branches of the gemtexter sites: unrelated histories that the forge
# compare reports as 0 ahead. They are live and must never be listed.
KEEP = {(repo, "content-" + kind) for repo in ("foo.zone", "pages") for kind in ("gemtext", "html", "md")}


def rows(datadir, name, width):
    with open(os.path.join(datadir, name), newline="") as f:
        return [r + [""] * (width - len(r)) for r in csv.reader(f, delimiter="\t") if r]


def unique_patches(repo, base, ref):
    """Commits on ref with no patch-equivalent commit on base; None if git fails
    (e.g. the sha is not present in this clone)."""
    rc, out = run("git", "-C", repo, "cherry", base, ref)
    return None if rc != 0 else sum(1 for line in out.splitlines() if line.startswith("+"))


def classify_remote(row, pr_states):
    """Return (is_candidate, reason) for one GitHub/Forgejo branch row."""
    _forge, repo, default, branch, _date, ahead, _behind, sha, flags = row
    states = pr_states.get((repo, branch), set())
    if "archived" in flags:
        return False, "repo is archived; unarchive or delete the repo"
    if "OPEN" in states:
        return False, "has an open PR"
    if ahead == "0":
        return True, "fully merged into " + default
    if "MERGED" in states:
        return True, "PR merged (squash/rebase)"
    local = os.path.join(HOME, "git", repo)
    if os.path.isdir(local) and unique_patches(local, default, sha) == 0:
        return True, "all commits patch-equivalent in " + default
    return False, "unmerged commits, no merged PR"


def remote_branches(datadir):
    pr_states = collections.defaultdict(set)
    for repo, branch, state, _num in rows(datadir, "prs.tsv", 4):
        pr_states[(repo, branch)].add(state)
    cand, review, known, tips = [], [], set(), {}
    for row in rows(datadir, "gh.tsv", 9) + rows(datadir, "fj.tsv", 9):
        forge, repo, default, branch, date, ahead, behind, sha, _flags = row
        known |= {(repo, branch), (repo, default)}
        if (repo, branch) in KEEP:
            continue
        ok, reason = classify_remote(row, pr_states)
        line = f"{repo}\t{branch}\t{date}\t+{ahead}/-{behind}\t{sha}"
        (cand if ok else review).append((forge, line, reason))
        if ok:
            tips[(repo, sha)] = reason
    return cand, review, known, tips


def local_branches(datadir, remote_tips):
    cand, review = [], []
    for repo, base, kind, branch, date, ahead, behind, _track in rows(datadir, "local.tsv", 8):
        name = os.path.basename(repo)
        if kind != "local" or (name, branch) in KEEP:
            continue
        ref = f"refs/heads/{branch}"
        sha = run("git", "-C", repo, "rev-parse", "--short=10", ref)[1] or "?"
        line = f"{os.path.relpath(repo, HOME + '/git')}\t{branch}\t{date}\t+{ahead}/-{behind}\t{sha}"
        uniq = unique_patches(repo, base, ref)
        if ahead == "0":
            cand.append((line, "fully merged into " + base))
        elif uniq == 0:
            cand.append((line, "all commits patch-equivalent in " + base))
        elif (name, sha) in remote_tips:
            cand.append((line, "same tip as remote branch: " + remote_tips[(name, sha)]))
        else:
            review.append((line, f"{uniq} commit(s) not found in {base}"))
    return cand, review


def stale_tracking_refs(datadir, known):
    """Remote-tracking refs whose branch name is on neither GitHub nor Forgejo.
    Name matching only: a remote pointing elsewhere (upstream, Codeberg) may
    still have the branch, so these need a look before pruning."""
    stale = []
    for repo, _base, kind, ref, date, ahead, behind, _track in rows(datadir, "local.tsv", 8):
        remote, _, branch = ref.partition("/")
        if kind == "remote" and (os.path.basename(repo), branch) not in known:
            line = f"{os.path.relpath(repo, HOME + '/git')}\t{remote}/{branch}\t{date}\t+{ahead}/-{behind}"
            stale.append((line, "remote branch gone"))
    return stale


def emit(out, title, items, note=None):
    out.write(f"\n## {title} ({len(items)})\n")
    if note:
        out.write(f"# {note}\n")
    for line, reason in sorted(items):
        out.write(f"{line}\t# {reason}\n")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    datadir, outpath = sys.argv[1:]
    rc, rr, known, tips = remote_branches(datadir)
    lc, lr = local_branches(datadir, tips)
    stale = stale_tracking_refs(datadir, known)
    with open(outpath, "w") as out:
        out.write(f"# Obsolete branch candidates, generated {datetime.date.today()}. Nothing has been deleted.\n"
                  "# Columns: repo, branch, tip date, +ahead/-behind vs default branch, tip sha, # reason\n"
                  "# Local repos were scanned without fetching. Codeberg is archived and not checked.\n")
        for forge in ("GitHub", "Forgejo"):
            emit(out, f"DELETE CANDIDATES - {forge}", [(l, r) for f, l, r in rc if f == forge.lower()])
        emit(out, "DELETE CANDIDATES - local branches", lc)
        emit(out, "DELETE CANDIDATES - stale remote-tracking refs", stale,
             "name-matched against GitHub/Forgejo only; check where the remote points, then git fetch --prune")
        out.write("\n\n# ---- NOT candidates: listed for review only ----\n")
        for forge in ("GitHub", "Forgejo"):
            emit(out, f"REVIEW - {forge}", [(l, r) for f, l, r in rr if f == forge.lower()])
        emit(out, "REVIEW - local branches", lr)
    print(f"candidates: remote {len(rc)}, local {len(lc)}, stale refs {len(stale)}; "
          f"review: remote {len(rr)}, local {len(lr)} -> {outpath}")


if __name__ == "__main__":
    main()
