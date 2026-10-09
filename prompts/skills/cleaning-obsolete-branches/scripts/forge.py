"""Shared helpers for the branch-cleanup scripts: forge endpoints from the gitsyncer
config, plus thin GitHub (gh CLI) and Forgejo (anonymous HTTP) API wrappers."""
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "gitsyncer", "config.json")
MAIN_NAMES = ("main", "master")


def load_forges():
    """Return (github_owner, forgejo_api_base, forgejo_owner, forgejo_ssh_host).

    Endpoints are read from the gitsyncer config so the Forgejo host/port has a
    single canonical home and is not repeated in these scripts."""
    with open(CONFIG) as f:
        orgs = json.load(f)["organizations"]
    github = next(o["name"] for o in orgs if "github.com" in o["host"])
    forgejo = next(o for o in orgs if o.get("forgejo_api_base"))
    return github, forgejo["forgejo_api_base"].rstrip("/"), forgejo["forgejo_owner"], forgejo["host"]


def quote(ref):
    return urllib.parse.quote(ref, safe="")


def run(*cmd, cwd=None):
    """Run a command; return (exit code, combined output)."""
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return p.returncode, (p.stdout + p.stderr).strip()


def gh(path):
    """GET a GitHub API path; None on error."""
    p = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    return json.loads(p.stdout) if p.returncode == 0 else None


def gh_paged(path):
    p = subprocess.run(["gh", "api", "--paginate", "--slurp", path],
                       capture_output=True, text=True, check=True)
    return [item for page in json.loads(p.stdout) for item in page]


def fj(api_base, path, retries=2):
    """GET a Forgejo API path anonymously; None on error. Compare calls on large
    repos occasionally time out, hence the retries."""
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(api_base + path, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:  # noqa: BLE001 - report and carry on
            if attempt == retries:
                print(f"forgejo error {path}: {e}", file=sys.stderr)
    return None


def fj_paged(api_base, path):
    items, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        chunk = fj(api_base, f"{path}{sep}limit=50&page={page}")
        if not chunk:
            return items
        items += chunk
        page += 1
