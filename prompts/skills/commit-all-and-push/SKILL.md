---
name: commit-all-and-push
description: "Commit all current project changes and synchronize the current branch and all tags to all configured upstream Git repositories. Use when explicitly invoked as commit-all-and-push; handles rebases, conflicts, verification, and unavailable upstream repositories."
disable-model-invocation: true
---

# Commit All and Push

Run only when explicitly requested. Invocation authorizes committing the current
project's pending changes, resolving necessary integration conflicts, and pushing
the current branch and all tags to all configured upstream repositories. Here,
upstream repositories means every Git remote and each of its push destinations.
Work through
routine conflicts without asking again. Other branches, releases, unrelated
repositories, service startup and repository administration are outside this scope.

## Inspect and checkpoint

- Find the Git root and read its applicable instructions. Inspect branch, status,
  staged/unstaged diffs and untracked files from the root. Include intended existing
  edits as well as this session's work: this is a request to commit all changes.
  Honor ignore rules and local secret-file conventions; exclude generated caches
  and build artifacts. Report exclusions and leave them intact. Coordinate with
  live workers before staging their unfinished work.
- Inspect an existing rebase/merge before proceeding; do not blindly abort it.
  Detached HEAD or an ambiguous destination branch needs clarification before any
  push. Do not invent a branch name or reset away changes.
- Run the project's relevant checks and fix failures introduced by the changes.
  Record any baseline failures or unavailable checks accurately. Never publish
  known-broken work or call unrun checks successful.
- Stage the reviewed paths, including deletions, review the staged diff and commit
  with a useful message. Commit nothing if the tree is already clean. A clean tree
  still needs remote and tag synchronization. Preserve a recovery ref for the
  original branch tip before rewriting history; never overwrite an existing ref.

## Discover and fetch every destination before pushing

- Enumerate remote names and **all push URLs** (`git remote get-url --push --all
  <remote>`). Do not assume `origin`, infer a hostname from a remote name, or rely
  on `git push`'s default refspec. Deduplicate identical endpoints while recording
  their remote aliases. Distinct push URLs on one remote are separate destinations;
  fetch URLs may point somewhere else. Do not print credential-bearing URLs.
- Probe each push endpoint noninteractively with a bounded connection timeout;
  for example use `timeout 30s git ls-remote ...` where available and an SSH
  `ConnectTimeout`/`BatchMode=yes`. Preserve existing authentication configuration.
  Fetch the destination's branch and tags into unique temporary refs so one
  mirror cannot overwrite another mirror's refs or local tags. Inspect configured
  upstream/fetch history when needed to identify published commits.
- An unavailable upstream repository must not block synchronization with the others.
  Record offline, archived/read-only and authentication failures separately,
  continue with the reachable writable destinations, and report partial success.
  Do not start remote services, unarchive a repository or change access settings.
  A successful read probe does not prove write access; handle push refusals too.
- Import collision-free remote-only tags so the final tag set includes every
  reachable destination's tags. Compare the actual tag ref object IDs, including
  annotated tag objects, not just peeled commit IDs. If the same tag name points
  to different objects, preserve every original ref and report a blocking tag
  conflict. Never force-update, delete or silently rename a tag. Continue publishing
  the branch and uncontested tags where safe; clearly identify unsynchronized tags.

## Reconcile histories and verify

- Inspect the graph before choosing an integration base. If a remote is ahead and
  the local tip is its ancestor, fast-forward. If every remote tip is already an
  ancestor of local HEAD, no rebase is needed.
- When local unpublished commits diverge from an advanced remote, rebase that
  unpublished work onto the fetched remote history before pushing. Use
  `--rebase-merges` if needed to retain intentional local merges. Never rewrite
  published or tagged history just to make mirrors agree.
- Independently diverged remote histories must all survive integration. Preserve
  their tips with merges when necessary, then replay only a clearly identified
  unpublished local suffix. If no safe rebase boundary exists, merge rather than
  rewrite published/tagged commits. A final ancestry check must show that **every
  fetched destination tip** is an ancestor of the result. Do not use a force push
  to conceal a missing remote history or allow unrelated histories automatically.
- Resolve conflicts by reading both sides and their intent; avoid blanket
  `--ours`/`--theirs`. Fix generators/inputs for generated-file conflicts and
  regenerate outputs. Continue the operation and examine its complete diff.
  Pause only when a semantic choice cannot be inferred safely; preserve work and
  state the exact unresolved decision.
- After any rebase, merge or conflict resolution, rerun the build/tests/lint
  required for the resulting changes. Review the final combined changes, not just
  conflict markers. Fix integration regressions and commit those fixes before
  publishing. Existing tags stay on their original objects; creating a new tag or
  changing a release version is not part of this workflow.

## Push and confirm

- Push the current branch explicitly to the same branch name at each available
  destination, and push **all local tags**, including lightweight and annotated
  tags and the collision-free remote-only tags imported above. Do not substitute
  `--follow-tags`, which omits some tags, or `--all`, which publishes other branches.
- Prefer an atomic branch-and-tags push per endpoint where supported. If atomic
  pushes are unsupported, push branch and tags separately and track each result.
  With no tag collisions, the ordinary form is an explicit branch push followed
  by `git push <destination> --tags`. With collisions, use explicit refspecs for
  uncontested tags. Never use `--force`, `--force-with-lease`, `--mirror` or pruning.
- If another writer advances a branch, fetch again, reconcile, resolve and rerun
  affected checks. Retry at most three integration/push rounds; then report the
  competing update. If HEAD changes after a mirror was pushed, revisit **every**
  available destination so they end at the same final commit.
- Read remote refs back and compare the branch object ID and every expected tag
  object ID with local refs. Do not claim full synchronization merely because a
  push command returned success. Preserve recovery refs until verification is
  complete; remove only temporary refs created by this invocation once safe.
- Where a push destination is also a remote's fetch endpoint, refresh its matching
  branch tracking ref after verification. Direct URL pushes can otherwise leave
  `git status` incorrectly showing ahead. If fetch and push endpoints differ,
  preserve the tracking ref's fetch semantics and explain that status separately.
- Report the final commit and branch, checks actually run, rebase/conflict work,
  branch/tag verification per destination, and any skipped endpoints or tags.
  Finish with `git status`; explain remaining files rather than silently hiding
  them. Continue useful synchronization even when one endpoint is unavailable.
