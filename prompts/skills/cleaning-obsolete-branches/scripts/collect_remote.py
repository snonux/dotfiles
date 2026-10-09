#!/usr/bin/env python3
"""Read-only collectors for GitHub and Forgejo. All output is TSV on stdout.

  collect_remote.py github          non-default branches: forge repo default branch date ahead behind sha flags
  collect_remote.py forgejo         same columns
  collect_remote.py prs <gh.tsv>    same-repo PRs of the repos in gh.tsv: repo head-branch state #number
  collect_remote.py defaults        repos whose default branch is not main/master:
                                    forge repo default available(main,master) flags
"""
import sys

from forge import MAIN_NAMES, fj, fj_paged, gh, gh_paged, load_forges, quote, run

GH_OWNER, FJ_API, FJ_OWNER, _ = load_forges()


def flags_of(repo, names):
    return ",".join(n for n in names if repo.get(n))


def github_repos():
    return gh_paged("/user/repos?affiliation=owner&per_page=100")


def forgejo_repos():
    return fj_paged(FJ_API, f"/orgs/{FJ_OWNER}/repos")


def github_rows():
    for repo in github_repos():
        name, default = repo["name"], repo["default_branch"]
        for br in gh_paged(f"/repos/{GH_OWNER}/{name}/branches?per_page=100"):
            if br["name"] == default:
                continue
            cmp_ = gh(f"/repos/{GH_OWNER}/{name}/compare/{quote(default)}...{quote(br['name'])}") or {}
            commit = gh(f"/repos/{GH_OWNER}/{name}/commits/{br['commit']['sha']}") or {}
            date = commit.get("commit", {}).get("committer", {}).get("date", "?")[:10]
            yield ("github", name, default, br["name"], date, cmp_.get("ahead_by", "?"),
                   cmp_.get("behind_by", "?"), br["commit"]["sha"][:10], flags_of(repo, ("fork", "archived")))


def forgejo_rows():
    for repo in forgejo_repos():
        name, default = repo["name"], repo["default_branch"]
        base = f"/repos/{FJ_OWNER}/{name}"
        for br in fj_paged(FJ_API, f"{base}/branches"):
            if br["name"] == default:
                continue
            # Forgejo's compare only reports the ahead side, so ask both ways.
            ahead = (fj(FJ_API, f"{base}/compare/{quote(default)}...{quote(br['name'])}") or {}).get("total_commits", "?")
            behind = (fj(FJ_API, f"{base}/compare/{quote(br['name'])}...{quote(default)}") or {}).get("total_commits", "?")
            yield ("forgejo", name, default, br["name"], br["commit"]["timestamp"][:10], ahead, behind,
                   br["commit"]["id"][:10], flags_of(repo, ("fork", "archived", "mirror")))


def pr_rows(gh_tsv):
    repos = sorted({line.split("\t")[1] for line in open(gh_tsv) if line.strip()})
    query = '.[] | select(.isCrossRepository|not) | [.headRefName, .state, "#\\(.number)"] | @tsv'
    for repo in repos:
        rc, out = run("gh", "pr", "list", "-R", f"{GH_OWNER}/{repo}", "--state", "all", "--limit", "1000",
                      "--json", "headRefName,state,number,isCrossRepository", "-q", query)
        for line in out.splitlines() if rc == 0 else []:
            yield (repo, *line.split("\t"))


def default_rows():
    for repo in github_repos():
        if repo["default_branch"] not in MAIN_NAMES:
            names = [b["name"] for b in gh_paged(f"/repos/{GH_OWNER}/{repo['name']}/branches?per_page=100")]
            yield ("github", repo["name"], repo["default_branch"],
                   ",".join(n for n in MAIN_NAMES if n in names), flags_of(repo, ("fork", "archived")))
    for repo in forgejo_repos():
        if repo["default_branch"] not in MAIN_NAMES and not repo.get("empty"):
            names = [b["name"] for b in fj_paged(FJ_API, f"/repos/{FJ_OWNER}/{repo['name']}/branches")]
            yield ("forgejo", repo["name"], repo["default_branch"],
                   ",".join(n for n in MAIN_NAMES if n in names), flags_of(repo, ("fork", "archived", "mirror")))


def main():
    modes = {"github": github_rows, "forgejo": forgejo_rows, "defaults": default_rows}
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "prs" and len(sys.argv) == 3:
        rows = pr_rows(sys.argv[2])
    elif mode in modes:
        rows = modes[mode]()
    else:
        sys.exit(__doc__)
    for row in rows:
        print("\t".join(str(c) for c in row), flush=True)


if __name__ == "__main__":
    main()
