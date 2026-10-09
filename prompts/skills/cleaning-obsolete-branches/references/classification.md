# Classification and Pitfalls

How `scripts/make_candidates.py` sorts branches, and what was learned on the
first full cleanup (2026-10-09: 165 GitHub + 46 Forgejo non-default branches,
144 fully merged ones deleted).

## Delete candidates

A branch is a candidate when one of these holds, checked in this order:

| Reason in the file | Meaning | Deleted by `delete_merged.py`? |
|--------------------|---------|--------------------------------|
| `fully merged into <default>` | 0 commits ahead of the default branch | yes, after a live re-check |
| `PR merged (squash/rebase)` | commits ahead, but a same-repo PR from this branch is MERGED and none is OPEN | no |
| `all commits patch-equivalent in <default>` | `git cherry` finds every commit as an identical patch (rebased or cherry-picked work) | no |
| `same tip as remote branch: …` | local branch pointing at a remote candidate's sha | no |

Only the first group is provable from ancestry alone, which is why the delete
script is limited to it. For the other groups, delete only when the user asks
for that group by name, and re-check each branch at that moment:

- squash-merged: the branch tip must still equal the merged PR's head sha
  (`gh pr view <n> --json headRefOid,state`), otherwise commits were pushed
  after the merge and would be lost;
- patch-equivalent: `git cherry <default> <branch>` must still print no `+` line.

## Review only (never auto-candidates)

- `unmerged commits, no merged PR` — real or historical work. Old version
  branches (`ychat` 0.x, `fype` build-*) look like archives; tagging them
  preserves the history if the user wants the branches gone.
- `has an open PR`.
- `repo is archived` — the forge refuses branch deletion on archived repos; the
  decision is about the repo, not the branch.
- local branches with commits not found in the default branch. Agent worktree
  branches (`worktree-agent-*`) often land here even though their work was
  reworked into main: the worktrees are gone, but ancestry cannot prove it.

## Never delete

- `foo.zone` and `pages` branches `content-gemtext`, `content-html`,
  `content-md`: live gemtexter publishing branches with unrelated histories.
  Forgejo's compare reports them as 0 ahead / 0 behind, so they would look
  merged; `make_candidates.py` excludes them via `KEEP`. Add any new publishing
  branch there.
- A branch that is checked out locally (`delete_merged.py` skips it).

## Pitfalls

- **A wrong default branch hides obsolete branches.** Branches are measured
  against the forge's default. When a stale `develop` was the GitHub default,
  `master` showed up as "ahead" and `develop` was never listed. Fix defaults
  (workflow step 1), then collect again — data collected before the switch is
  misleading for those repos.
- **`foo.zone` on GitHub** defaulted to `content-gemtext` and was switched to
  `main` on 2026-10-09 at the user's request ("the default should always be
  main or master"). gitsyncer's `showcase_stats_branches` still points at
  `content-gemtext`; that is a separate setting.
- **Repos without main/master** (`Adv360-Pro-ZMK` → `V3.0`, `ds-sim` →
  `ds-sim`, as of 2026-10-09) cannot be fixed by switching the default; they
  need a rename on each forge plus every clone. Ask before doing that.
- **Codeberg is archived.** All `codeberg.org/snonux` repos are read-only and
  gitsyncer does not sync them (`sync_codeberg` unset), so branches still
  present there do not come back and need no cleanup.
- **Forgejo.** Reads work anonymously over the API; deletion goes over git+ssh
  with `--force-with-lease`, so no API token is needed. Compare calls on big
  repos sometimes time out: the value becomes `?` and the branch lands under
  REVIEW instead of being guessed.
- **Forgejo can lag behind GitHub.** A branch may be 0 ahead on GitHub but ahead
  on Forgejo because Forgejo's default branch has not been synced yet. Sync the
  default first rather than deleting on the lagging forge.
- **Local scans do not fetch.** Ahead/behind for local and remote-tracking refs
  reflect the last fetch. Remote verdicts come from the forge APIs, not from
  these refs.
- **Stale remote-tracking refs are name-matched** against GitHub and Forgejo
  only. A remote pointing at an upstream project (forks such as `libbpfgo`,
  `Adv360-Pro-ZMK`) may still have the branch. After a remote cleanup this
  section grows a lot (every deleted branch leaves a tracking ref per clone);
  `git -C <repo> fetch --prune <remote>` clears them.
- **gitsyncer work dir.** Its clones mirror the forges; local branches there
  follow once the remotes are clean. `exclude_branches` in the gitsyncer config
  (`^codex/`) keeps matching branches from being synced at all.
