---
name: audit-next-repo
description: "Show the top 5 git repos due for a code audit (ranked by LOC churn since the last audit/<date> marker, with stats explaining why each is due) and let the user pick one to audit. On selection, stamp the start audit/<date> tag (audit-tagging skill, local safety net), run a full code-quality audit (auditing-code-quality skill — which creates finding tasks, a +audit closure gate, and a final +audit tagging task that moves/pushes the end marker after fixes), record findings as tasks via agent-task-management within the audited repo. Do not stamp or push an immediate post-audit end marker here — auditing-code-quality owns that delayed end tag so the next audit-due run measures churn from the end of the fix cycle. The user can also defer a repo (tag it to skip this cycle) or stop. Uses ~/scripts/audit-due. Triggers on: audit next repo, next code audit, which repo to audit, code audit due, run audit-due."
---

# Audit Next Repo

Show the **top 5** repositories most due for a code audit with stats explaining
why each is due, let the **user pick one** to audit, then run the audit and
record findings as tasks **within that repo**. This skill is the entry point
that ties together `~/scripts/audit-due`, `auditing-code-quality`, and
`agent-task-management`.

**Core rule: never auto-audit.** Always present the top 5 and let the user
select. Only tag a repo to **defer** it when the user explicitly defers that
specific repo — do not pre-emptively tag repos to hide them. A repo without a
recent audit marker is genuinely due and should stay due until the user either
audits it or explicitly defers it.

**Excluded repos (never audit):** `conf_private`, `libbpfgo`, `ds-sim` are
permanently excluded from auditing. Filter them out of the due list in step 2
and never offer, audit, or defer-tag them — even if the user picks a slot they
occupied. This list is user-maintained: add a repo here when the user says it
should never be audited, and remove it if they retract the exclusion.

## When to Use

- "Which repo should I audit next?", "audit next repo", "code audit due",
  "run a code audit", "what's due for audit".
- You want a deterministic, repeatable audit cadence across `~/git/*` repos
  rather than auditing ad-hoc.

## Prerequisites

- `~/scripts/audit-due` must be installed (it ships with the dotfiles; install
  via `rex home_scripts` if missing). It is a plain bash script with no deps
  beyond git + coreutils.
- The `ask` CLI (`~/go/bin/ask`) for task management within the audited repo.

## Workflow

The workflow is a loop: discover → **present top 5 with stats** → **user picks
one** → audit-or-defer → repeat or stop.

### 1. Discover what is due

Run the script from anywhere:

```sh
~/scripts/audit-due
```

Read the table (the DUE column is `due`/`no`; churn = LOC column). If nothing
is due, stop and tell the user. Tuning (optional, via env):
- `LOC_THRESHOLD=2000` — churn (insertions + deletions) that triggers an audit.
- `audit-due --all` — also show not-due repos (for triage).
- `audit-due --json` — machine-readable output (one JSON object per repo, with
  a `skills` array) — **use this for step 2** so you can sort/parse precisely.

### 2. Present the top 5 due repos with stats

Run `audit-due --json`, **drop the excluded repos** (see "Excluded repos
(never audit)"), and rank the remaining due repos by **churn** (the `loc`
field, descending). Present the **top 5** as a numbered table so the user can
pick. Fill the freed slots with the next-highest-churn due repos.
For each, show the stats that explain **why** it is due:

- **#** (1–5)
- **Repo**
- **Lang** (detected language → which skill set applies)
- **Churn** (LOC changed since the last marker — this is the due signal)
- **Commits** since the marker
- **Marker** — the `audit/*` tag/commit that is the baseline, or `(none)`
- **Since** — the marker commit's date
- **Why** — one short clause: `real marker, genuine debt` when MARKER ≠
  `(none)`; `no marker — whole-history churn (needs a baseline tag)` when
  MARKER = `(none)`.

Example layout:

```
#  Repo         Lang  Churn  Commits  Marker     Since        Why
1  ior          go    62476   320    d78a253    2026-05-06   real marker, genuine debt
2  player       go     8654    23    1824175    2026-05-22   real marker, genuine debt
3  fastforge    c      8400    56    9d28ec3    2026-04-12   real marker, genuine debt
4  goprecords   go     5062    34    f143b6d    2026-04-14   real marker, genuine debt
5  dtail        go    130065   472   (none)     2020-01-09   no marker — whole-history churn (needs a baseline tag)
```

If fewer than 5 repos are due, show all of them. When churn is comparable,
rank repos with a **real marker** above `(none)` repos, since real-marker
churn is the trustworthy signal (whole-history churn from `(none)` is
inflated and usually needs a baseline tag, not necessarily an audit next).

### 3. Ask the user to select one (do not skip this step)

Ask the user which repo to audit, by number or name, e.g.:

> Which repo do you want to audit? Pick a number (1–5) or name, or say
> `defer <#>` to skip one, or `stop`.

Wait for the user's answer. Branch:

- **a number or name** (audit) → that repo goes to step 4 (switch in + **tag
  at the START**), then step 5 (run the audit end-to-end via
  **auditing-code-quality**, including finding tasks, gate, and delayed
  tagging task), step 6 (confirm tasks were recorded), step 7 (report).
  After reporting, you may loop back to step 1 to offer the next batch —
  but only if the user wants to continue.
- **`defer <#>`** (skip one) → tag that repo's current HEAD with
  `audit/<date>` now (see step 4 for the exact tag command and the
  today-collision suffix rule) so it drops off the due list until another
  ≥threshold LOC of changes; tell the user it was deferred; then loop back to
  step 1 to offer the next batch (or stop if the user says so).
- **`stop`** (or "that's all") → stop. Do not tag anything. Leave the
  remaining due repos untouched so they stay due for next time.

Never proceed to audit or tag without an explicit user answer to this prompt.
Only the repo the user picked gets audited; only a repo the user explicitly
`defer`-ed gets a defer tag.

### 4. Switch in and TAG AT THE START (audit mode)

Operate **inside** the chosen repo for the rest of the workflow. Pass its
absolute path as the `cwd` of subsequent tool calls (do not chain `cd` with
`&&`).

**Tag the START marker BEFORE doing any audit work.** Load the
**audit-tagging** skill and follow its "Start tag" step: stamp `audit/<date>`
on the repo's current `HEAD` and keep the name in `$START_TAG`. The start
tag is a **local-only safety net** — it survives a context loss so the next
`audit-due` still sees a fresh baseline — and is **not** the final marker.
The **auditing-code-quality** workflow §6 tagging task (after the closure
gate) moves and pushes that same name to the post-fix `HEAD`. Pass
`$START_TAG` into that skill's run (annotate the tagging task with the exact
string). The audit-tagging skill owns naming (incl. `-N` collision suffix)
and push rules; do not re-derive them here.

```sh
START_TAG="audit/$(date +%F)"   # audit-tagging skill: append -2,-3 on collision
git tag "$START_TAG"              # local only — do not push (ACQ §6 pushes the end tag)
```

**Defer mode** (user said `defer <#>`): per the audit-tagging skill's
"Defer mode" — stamp the tag once at decision time, no start/end pair, no
audit work. Only defer a repo the user explicitly named; never bulk-defer.

### 5. Run the audit

Load the **auditing-code-quality** skill and follow its workflow end-to-end on
the repo (including task creation, the `+audit` closure gate, and the final
`+audit` tagging task that depends on the gate). It orchestrates the
specialized sub-skills; the `audit-due` output already tells you which
language-specific skills apply (e.g. for Go: `100-go-mistakes` +
`go-best-practices`; for C: `c-best-practices`; for Bash: `bash-best-practices`).
Prefer sub-agents so each audit pass has a fresh context, as
`auditing-code-quality` directs.

Because step 4 already stamped `$START_TAG`, **auditing-code-quality** must
**not** stamp a second start tag — reuse the existing name and put the exact
`$START_TAG` string in the tagging-task annotation.

For a large repo, **scope the audit** rather than auditing the whole codebase
in one pass: focus on the highest-churn files since the last audit marker
(e.g. `git diff --name-only <marker> HEAD`, then the top files by net-new
LOC). State the scope you chose.

### 6. Confirm findings were recorded WITHIN the repo

**auditing-code-quality** already creates `ask` tasks inside the audited repo.
Confirm they landed here (not elsewhere). Follow its exact task format.

**Tag-name caveat:** the `ask` CLI rejects hyphens in tags — `+code-quality`
silently lands in the description instead of as a tag. Use **`+codequality`**
(no hyphen). `+bugfix` works as-is.

Do **not** create a separate re-tag task here — **auditing-code-quality**
workflow §6 owns the single post-gate tagging task. Do **not** move or push
the audit marker immediately after filing findings; leave the local start tag
until that tagging task runs.

### 7. Report (audit mode only)

Summarize for the user:
- Which repo was audited (or deferred) and its pre-audit churn.
- Marker status:
  - If finding tasks were created: the local start marker name (`$START_TAG`)
    and that the **end** marker will be moved/pushed by the final `+audit`
    tagging task after the closure gate (post-fix `HEAD`).
  - If **zero** finding tasks (gate/tagging skipped): that
    **auditing-code-quality** already finalized `$START_TAG` as the end
    marker (move + push) so the clean audit still has a shared baseline —
    do not claim a tagging task exists.
- Counts: bugs found, design findings, tasks created (by severity).
- When they exist: the **gate** and **tagging** task ids from
  **auditing-code-quality**, and that `next-auto-task` / `next task` will
  re-verify then stamp the marker.
- Then offer the next batch (loop to step 1) or stop per the user.

## Bootstrapping repos without tags

For a repo that has no `audit/*` tag and no keyword-matchable audit commit,
`audit-due` reports "no audit marker - full history" (whole-history churn).
See the **audit-tagging** skill's "Bootstrapping a repo with no marker"
section for the exact commands (`audit-due bootstrap` or manual
`git tag audit/<date> <commit>`). Do not bootstrap repos the user hasn't asked
about; for a repo with no meaningful audit history, tag the current HEAD
after its first proper audit instead (step 4 start tag; end marker via
**auditing-code-quality** workflow §6 after fixes).

## Rules

- **Always show the top 5 and let the user pick.** Never auto-audit; never
  bulk-defer. One explicit selection per repo.
- **Never audit excluded repos.** `conf_private`, `libbpfgo`, `ds-sim` are
  filtered out of the due list and out of the top 5; they are never audited,
  offered, or defer-tagged unless the user explicitly lifts the exclusion.
- **One repo per audit pass.** Don't audit multiple repos in one session.
- **Findings stay in the repo.** Create `ask` tasks inside the audited repo's
  working directory, never in a shared/parent location.
- **Do not create a parallel re-tag task or immediate end tag.** Step 4
  stamps a local start tag only. **auditing-code-quality** owns the gate and
  the single post-gate `+audit` tagging task that moves/pushes
  `audit/<date>` to the post-fix `HEAD`. Never race that with a step-6a-style
  task or an immediate post-audit `git tag`/`git push`.
- **Tagging lives in the audit-tagging skill.** Step 4 stamps a local-only
  start tag (safety net); ACQ §6 moves it to the post-fix `HEAD` and pushes
  it remotely. Naming (`audit/<date>` + `-N` collision suffix), the exact
  `git tag -d` / `git tag` / `git push origin --force` incantations, the
  protected-tag fallback, defer-mode tagging, and bootstrapping a repo with
  no marker are all defined there — load **audit-tagging** rather than
  re-deriving them. Never leave both start and end tags; never leave only
  the start tag if the fix cycle finished.
- **Use `+codequality`, not `+code-quality`.** `ask` rejects hyphenated tags.
- **Use the script, don't reimplement it.** LOC math and marker detection
  live in `~/scripts/audit-due`; this skill only orchestrates around it.
  Tagging mechanics live in the **audit-tagging** skill.
- **End-marker push is not this skill's job.** ACQ workflow §6 (or ACQ's
  zero-findings finalize path) follows **audit-tagging** to push the end
  marker; this skill never pushes except optional defer-mode tags when the
  user wants the skip recorded remotely. The start tag stays local until
  that end step.