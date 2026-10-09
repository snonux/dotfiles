#!/usr/bin/env python3
"""Delete the branches marked 'fully merged into main|master' in a candidates file.

  delete_merged.py <candidates.txt>            dry run: re-verify only
  delete_merged.py <candidates.txt> --delete   verify, then delete

Every branch is re-verified live right before deletion: the tip must still be the
recorded sha and must have zero commits that are not in the default branch.
Squash-merged and patch-equivalent candidates are deliberately left alone.
Output TSV: section repo branch sha result  (keep it as the restore log)."""
import json
import os
import re
import sys

from forge import HOME, fj, load_forges, quote, run

GH_OWNER, FJ_API, FJ_OWNER, FJ_SSH = load_forges()
DRY = "--delete" not in sys.argv
MERGED = re.compile(r"\t# fully merged into (main|master)$")


def parse(path):
    """Yield (section, repo, branch, sha, base) for fully-merged delete candidates."""
    section = None
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("## "):
            kind = next((k for k in ("GitHub", "Forgejo", "local branches") if k in line), None)
            section = kind.split()[0].lower() if kind and "DELETE CANDIDATES" in line else None
            continue
        match = MERGED.search(line)
        if section and match:
            repo, branch, _date, _counts, sha = line.split("\t")[:5]
            yield section, repo, branch, sha, match.group(1)


def delete_github(repo, branch, sha, base):
    api = f"/repos/{GH_OWNER}/{repo}"
    rc, tip = run("gh", "api", f"{api}/branches/{quote(branch)}", "-q", ".commit.sha")
    if rc != 0 or not tip.startswith(sha):
        return f"SKIP tip changed or gone ({tip[:40]})"
    rc, out = run("gh", "api", f"{api}/compare/{quote(base)}...{quote(branch)}", "-q", ".ahead_by")
    if rc != 0 or out != "0":
        return f"SKIP not merged into {base} (ahead {out[:40]})"
    if DRY:
        return "would delete"
    rc, out = run("gh", "api", "-X", "DELETE", f"{api}/git/refs/heads/{branch}")
    return "deleted" if rc == 0 else "FAILED " + out[-120:]


def delete_forgejo(repo, branch, sha, base):
    api = f"/repos/{FJ_OWNER}/{repo}"
    tip = ((fj(FJ_API, f"{api}/branches/{quote(branch)}") or {}).get("commit") or {}).get("id", "")
    ahead = (fj(FJ_API, f"{api}/compare/{quote(base)}...{quote(branch)}") or {}).get("total_commits")
    if not tip.startswith(sha):
        return "SKIP tip changed or gone"
    if ahead != 0:
        return f"SKIP not merged into {base} (ahead {ahead})"
    if DRY:
        return "would delete"
    # Deleting over git+ssh needs no API token. The lease makes the server refuse
    # the delete if the tip moved since verification.
    rc, out = run("git", "push", f"--force-with-lease=refs/heads/{branch}:{tip}",
                  f"{FJ_SSH}/{FJ_OWNER}/{repo}.git", f":refs/heads/{branch}", cwd=HOME)
    return "deleted" if rc == 0 else "FAILED " + out[-160:]


def delete_local(repo, branch, sha, base):
    path, ref = os.path.join(HOME, "git", repo), f"refs/heads/{branch}"
    rc, tip = run("git", "-C", path, "rev-parse", "--short=10", ref)
    if rc != 0 or tip != sha:
        return f"SKIP tip changed or gone ({tip[:40]})"
    if run("git", "-C", path, "merge-base", "--is-ancestor", ref, f"refs/heads/{base}")[0] != 0:
        return "SKIP not an ancestor of " + base
    if run("git", "-C", path, "symbolic-ref", "-q", "HEAD")[1] == ref:
        return "SKIP currently checked out"
    if DRY:
        return "would delete"
    rc, out = run("git", "-C", path, "branch", "-D", branch)
    return "deleted" if rc == 0 else "FAILED " + out[-160:]


def main():
    args = [a for a in sys.argv[1:] if a != "--delete"]
    if len(args) != 1:
        sys.exit(__doc__)
    handlers = {"github": delete_github, "forgejo": delete_forgejo, "local": delete_local}
    for section, repo, branch, sha, base in parse(args[0]):
        result = handlers[section](repo, branch, sha, base)
        print(f"{section}\t{repo}\t{branch}\t{sha}\t{result}", flush=True)


if __name__ == "__main__":
    main()
