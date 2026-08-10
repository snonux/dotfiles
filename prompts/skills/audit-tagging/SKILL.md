---
name: audit-tagging
description: "Stamp and move the audit/<date> git tag markers that drive audit-due scheduling. Use when asked to tag for a code audit, set the audit start marker, finalize the audit end marker, move an audit tag, defer a repo from auditing, or bootstrap an audit baseline. Defines the start-tag (local safety net) -> end-tag (moved to post-audit HEAD, pushed remotely) workflow so the next audit-due run measures churn from the END of this audit, not from before it. Used by the audit-next-repo skill. Triggers on: audit tag, audit marker, tag for audit, finalize audit tag, move audit tag, defer audit, bootstrap audit marker."
---

# Audit Tagging

This skill owns the **`audit/<date>` git tag markers** that `~/scripts/audit-due`
reads to decide which repos are due for a code audit. It is the single
canonical home for the tagging rules; the `audit-next-repo` skill references
it instead of duplicating the details.

## The marker

`audit-due` ranks repos by LOC churn since the most recent `audit/*` tag
(`git describe --tags --match 'audit/*'`). So one `audit/<date>` tag per audit
is the baseline that "resets" a repo's churn counter.

## Naming

```sh
START_TAG="audit/$(date +%F)"     # e.g. audit/2026-08-11
```

- If `audit/<date>` for that day already exists, append `-2`, `-3`, …:
  `audit/2026-08-11-2`.
- Reuse the **exact same name** for the start and end tag of one audit (the
  end tag just moves that name to the post-audit commit). One canonical name
  per audit — never leave both a start and an end tag.
- Use the date the audit **starts** on (or the date the user asks for), even
  if the audit finishes the next day.

## Workflow: start tag (safety net) -> end tag (real marker)

The whole point is: the next audit must measure churn from the **end** of this
audit, not from before it. Otherwise the refactors/fixes this audit just
produced get re-counted as new debt on the next run.

### 1. Start tag — BEFORE any audit work

Stamp on the repo's current `HEAD` and remember the name (capture it in
`$START_TAG`). This is a **local-only safety net**: it guarantees a marker
exists even if the audit run is long and the agent loses context partway
through — the next `audit-due` run still sees a fresh baseline and does not
re-flag the repo immediately.

```sh
START_TAG="audit/$(date +%F)"
# append -2, -3, ... if today's audit/<date> already exists
git tag "$START_TAG"
```

- Do **not** push the start tag. It is local only — it will be moved to the
  post-audit `HEAD` in step 2 and the **end** tag is the one to push.
- This start tag is **not** the final audit marker. It only survives if the
  run loses context before step 2.

### 2. End tag — AFTER the audit + finding-recording are done

Replace the start marker with an end marker on the post-audit `HEAD`:
delete the start tag and recreate the same name at the current `HEAD`. Now
exactly one `audit/<date>` marker survives, and it marks the **end** of the
audit, so the next `audit-due` measures churn from here.

**Remind yourself to do this step.** It is easy to forget because the audit
already feels finished once findings are filed, but skipping it leaves the
start tag in place — which is only the loss-of-context safety net — and the
next audit re-counts the very LOC this audit changed. Always: end marker on,
start marker off.

```sh
# Move the tag from the pre-audit commit to the post-audit HEAD.
git tag -d "$START_TAG"
git tag "$START_TAG"          # same name, now points at the current HEAD
```

- Reuse the **exact** name from step 1 (same `$START_TAG`, including any
  `-N` suffix).
- If the audit produced no commits (only `ask` tasks filed outside the
  repo), `HEAD` is unchanged and the end marker lands on the same commit the
  start tag did — that is fine; deleting and recreating is still correct
  (the repo now has exactly one marker at this commit).
- If the run lost context before reaching this step, the start tag from
  step 1 survives as the baseline — the safety net working as designed; the
  next audit counts churn since the start of the interrupted audit, which is
  acceptable (better than re-auditing whole history).

### 3. Push the end marker remotely

The end marker should be pushed so the audit baseline is shared across
machines, clones, and CI:

```sh
git push origin --force "$START_TAG"   # force because the tag ref moved
```

- The force is needed because the same name moved from the start commit to
  the end commit.
- If the remote rejects the force-push (e.g. protected tags), delete the
  remote start tag first, then push normally:
  `git push origin :refs/tags/"$START_TAG"` then `git push origin "$START_TAG"`.
- The user can opt out of pushing; local tags are enough for local
  `audit-due` detection. The start tag is never pushed.

## Defer mode (skip a repo this cycle)

When a repo is explicitly deferred (not audited), stamp the tag once, at
decision time — no start/end pair, no audit work:

```sh
git tag "audit/$(date +%F)"     # + -N suffix on collision
```

This records "skipped on `<date>`" and drops the repo off the due list
until another ≥threshold LOC of changes. A defer tag may be pushed too if
the user wants the skip recorded remotely.

## Bootstrapping a repo with no marker

For a repo that has no `audit/*` tag and no keyword-matchable audit commit,
`audit-due` reports "no audit marker - full history" (whole-history churn).
To give it a real baseline:

```sh
audit-due bootstrap ~/git/<repo>      # stamps the keyword-detected commit
git -C ~/git/<repo> tag audit/<date> <commit>   # manual: pick the commit
```

Use `audit-due bootstrap` only when you trust the keyword-detected commit;
for a repo with no meaningful audit history, tag the current HEAD after its
first proper audit instead (the start-tag step above). Do not bootstrap
repos the user hasn't asked about.

## Rules

- **Start tag = local safety net; end tag = the real marker.** Never leave
  both; never leave only the start tag if the audit actually finished.
- **Move, don't add.** The end step deletes the start tag and recreates the
  same name at the post-audit `HEAD` — one canonical name per audit.
- **Push the end marker, not the start.** `git push origin --force
  "$START_TAG"`; start tag stays local.
- **Defer mode tags once, at decision time** — no start/end pair.
- **Don't push without the user's OK** (end marker should be pushed, but the
  user can opt out; defer tags only if the user wants them remote).