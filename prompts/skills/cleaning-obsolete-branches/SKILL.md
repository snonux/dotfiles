---
name: cleaning-obsolete-branches
description: "Audits and deletes obsolete git branches across GitHub, Forgejo and the local clones, and fixes repos whose default branch is not main or master. Deletes only fully merged branches, after review. Triggers on: obsolete branches, stale branches, merged branches, branch cleanup, delete branches, prune branches, claude/codex agent branches, default branch, fix default branch."
disable-model-invocation: true
---

# Cleaning Obsolete Branches

Find branches that are no longer needed on GitHub, Forgejo and in the local
clones, list them for review, and delete the ones that are provably merged.
Everything before the delete step is read-only.

## When to Use

- "Check my repos for obsolete / stale / merged branches"
- "Delete the merged branches", "clean up the claude/* branches"
- "The default branch should always be main or master"

## Reference Files

- [Classification and pitfalls](references/classification.md) — what makes a
  branch a delete candidate vs. review-only, the branches that must never be
  deleted, and the traps found while building this (wrong defaults masking
  obsolete branches, squash merges, archived repos, stale tracking refs).

Related skills, not duplicated here:

- Forgejo access, ports and exposure: [`f3s` Forgejo reference](../f3s/references/workloads/forgejo.md)
- Forge endpoints and owners come from `~/.config/gitsyncer/config.json`
  (`scripts/forge.py` reads them; do not hardcode the Forgejo host or port).

## Scripts

All in `scripts/`; run them with `bash` / `python3` explicitly (the login shell
is fish). They need `gh` (logged in as the repo owner) and `git`.

| Script | Does | Writes? |
|--------|------|---------|
| `collect_all.sh <datadir> [dirs...]` | runs all collectors into `<datadir>` (`gh.tsv`, `fj.tsv`, `prs.tsv`, `local.tsv`); dirs default to `~/git ~/git/gitsyncer-workdir` | no |
| `collect_remote.py defaults` | lists repos whose default branch is not main/master, and whether main/master exists | no |
| `make_candidates.py <datadir> <out.txt>` | classifies branches into DELETE CANDIDATES and REVIEW sections | no |
| `delete_merged.py <out.txt> [--delete]` | re-verifies, then deletes the `fully merged into main\|master` rows; dry run without `--delete` | only with `--delete` |

## Workflow

1. **Fix default branches first.** A wrong default hides obsolete branches (the
   stale branch is the base, so it is never listed) — see the reference.

   ```sh
   python3 scripts/collect_remote.py defaults
   gh api -X PATCH /repos/<owner>/<repo> -f default_branch=<main|master>
   ```

   Only switch when `main`/`master` already exists (4th column). A repo with
   neither needs a branch rename on every forge and clone: ask the user.
   Changing a default is outward-facing — do it only when the user asked for it.

2. **Collect** (a few minutes; one compare call per remote branch). Use a
   scratch directory for `<datadir>`.

   ```sh
   bash scripts/collect_all.sh <datadir>
   ```

3. **Classify** into a candidates file next to gitsyncer's own scripts:

   ```sh
   python3 scripts/make_candidates.py <datadir> ~/git/gitsyncer-workdir/obsolete_branch_candidates_$(date +%Y%m%d).txt
   ```

4. **Report** counts per section and the notable review items. Stop here unless
   the user asked for deletion.

5. **Delete** — only on an explicit request, and only the fully merged rows:

   ```sh
   python3 scripts/delete_merged.py <candidates.txt>            # dry run, expect "would delete"
   python3 scripts/delete_merged.py <candidates.txt> --delete > ~/git/gitsyncer-workdir/deleted_branches_$(date +%Y%m%d).tsv
   ```

   Report every `SKIP` / `FAILED` row. The TSV is the restore log (branch + tip sha).

6. **Anything else** (squash-merged, patch-equivalent, stale tracking refs,
   review rows) is deleted only when the user names that group; handle it per
   the reference rather than widening `delete_merged.py` silently.

## Restoring a Deleted Branch

The log has the tip sha. While the commit still exists on the forge or in a clone:

```sh
git push <remote> <sha>:refs/heads/<branch>     # remote
git branch <branch> <sha>                        # local
```
