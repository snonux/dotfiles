---
name: auditing-code-quality
description: >
  Run a comprehensive code quality audit through automated checks, defect
  hunting, and design review, using language and architecture references,
  then create actionable tasks for confirmed findings. Use when asked to
  "audit code quality", "full design review",
  "code health check", "architecture and code audit", or to combine design
  review with a bug sweep.
---

# Auditing Code Quality

Review the target once through three complementary passes. Reuse check results
and evidence across passes, then produce one report and remediation batch.

## Skills and References

- Go: [go-best-practices](../go-best-practices/SKILL.md) for conventions and
  checks, [100-go-mistakes](../100-go-mistakes/SKILL.md) for relevant pitfalls.
- Defects: [find-code-bugs](../find-code-bugs/SKILL.md), including one `ask`
  task per confirmed bug, whatever pass discovered it.
- Design: [solid-principles](../solid-principles/SKILL.md) for applicable
  type/interface contracts and [beyond-solid-principles](../beyond-solid-principles/SKILL.md)
  for system structure.
- Tracking: [agent-task-management](../agent-task-management/SKILL.md) owns
  `ask` syntax; [audit tagging](../audit/references/tagging.md) owns git markers.
- Metrics: [references/metrics.md](references/metrics.md) for the CRAP hotspot
  ranking (bundled `scripts/gocrap`), dead code, test quality and mutation
  testing, and the baseline the closure gate re-checks.

**go-best-practices** and **solid-principles** have explicit-only invocation
policies in `agents/openai.yaml`; read their files directly. Load other skills
through the available skill mechanism or read their files. Use references
within the passes below rather than running a separate full audit per skill.

## Scripts

- `scripts/crap-check.sh`: the one command to run. `crap-check.sh --all` prints
  the hotspot ranking for an audit; `crap-check.sh [base]` is the pass/fail
  review check for one change. Details: [references/metrics.md](references/metrics.md#1-hotspot-ranking-pass-a).
- `scripts/gocrap/`: the stdlib-only Go tool behind it. `main.go` holds the
  flags, `profile.go` parses coverprofiles, `funcs.go` scores and prints, and
  `changed.go` implements `-changed <rev>`. Tests are in `main_test.go` and
  `changed_test.go` (`go -C scripts/gocrap test ./...`; module file `go.mod`).

## Workflow

### 1. Identify Target Code

Determine what code to analyze:
- When files or a directory are provided, use those.
- When a class, module, or service is referenced by name, locate it.
- When ambiguous, ask which files or directories to scan.

Detect the primary language(s) of the target code to decide whether to include
the Go-specific skill.

If the target is inside a git repo and this run does not already have an
explicit `$START_TAG` from the caller (e.g. **audit** (`references/next-repo.md`) step 4), load
**audit** (`references/tagging.md`) and follow its **Start tag** step now — always stamp a new
start tag for this run; collision `-N` handles same-day reuse. Do **not** skip
Start tag merely because some `audit/<date>` tag already exists on the repo
(prior audits, defer tags, and end markers are indistinguishable by name).
Capture the exact `$START_TAG` string (including any `-N` suffix) for the
tagging task in workflow §6. Do not push the start tag.

### 2. Review in Three Passes

Read [the shared finding rules](references/report.md#shared-finding-rules) before
reviewing. Maintain one finding list throughout; retain evidence for the report.

#### A. Automated Checks

Inspect the project's documented build/test/lint commands and toolchain, then
run the appropriate checks once. For Go, load **go-best-practices** and include
`go build ./...`, `go vet ./...`, `go test -race ./...`, `gofmt -l .`, and
`errcheck ./...` where the environment supports them. Follow its verification
honesty rules for missing tools, dependencies, or expensive suites.

Then measure, following [references/metrics.md](references/metrics.md) §1–2:
for Go run `scripts/crap-check.sh --all` to rank functions by CRAP score
(complexity combined with test coverage) and run `staticcheck`. The other
tools listed there are optional. Passes B and C start from the
top of that ranking. Keep the ranking as the baseline for the closure gate.

Record commands, scope, results, and blockers. Diagnostics are investigation
inputs; establish their impact before classifying them as defects or design
findings. Later passes reuse these results; rerun only after changes or when
additional coverage is needed to resolve a specific concern.

#### B. Defect Hunting

Load **find-code-bugs** and follow its hunt method and finding-task rules on
the same scope, using pass A's results. For Go, also load **100-go-mistakes**:
consider its categories and read the specific references applicable to the
code and configured Go version. Use it to deepen this pass, not to repeat it.

Create one `+bugfix` task per confirmed bug. When a later design review confirms
a new defect, use these same rules to add its task without repeating the sweep.
Do not create the standalone bug-sweep closure gate or tagging task: workflow
§5–6 below owns close-out after all finding tasks exist.

For recurring failures, trace the shared premise before proposing another local
guard or retry. Identify the input, state transition, and observable result at
the boundary where the behavior goes wrong. Prefer a focused behavioral
reproduction when practical; a concrete reachable failure path is also evidence.

#### C. Design and Conventions

Load **beyond-solid-principles** and consider its ten lenses at the target's
scale, prioritizing simplicity, coupling, dependency direction, and failure
propagation. Load **solid-principles** where type/interface contracts or OO
design are relevant; skip inapplicable principles rather than forcing them
onto scripts or unrelated code. Read the applicable principle references.

Review Go conventions using the already-loaded **go-best-practices** and
relevant **100-go-mistakes** references. Apply the shared evidence rules;
separate convention differences from correctness defects. Use one design
finding for an underlying problem, even when multiple lenses describe it.

Then work through these four sub-steps in order:

1. **Design risks.** Look for domain states the code permits but the product
   forbids, repeated validation of the same input after its entry boundary,
   non-idempotent retry paths, and shared mutable state that could be
   separated. Recommend removing unneeded code or indirection before adding
   an abstraction. Metric scores from pass A decide where to look; they are
   not pass/fail thresholds.
2. **Naming.** If the project has a `GLOSSARY.md`, flag domain concepts that
   the code names differently from it, or names in two different ways.
3. **Test quality** ([references/metrics.md](references/metrics.md) §3). For
   the top hotspots and each finding, ask: would the tests still pass if the
   code did nothing? If `gremlins` is installed, run time-boxed mutation
   testing on the two or three riskiest packages. An unpinned behaviour whose
   failure matters is a finding.
4. **Repeat findings.** If earlier audits exist (`git tag -l 'audit/*'`,
   `ask completed +codequality`, `ask completed +bugfix`), check whether a
   current finding repeats a problem an earlier audit already fixed. Report
   a repeat as one finding about why it keeps coming back (the shared premise,
   missing enforcement, or the design that invites it), not as another local fix.

For large scopes, sub-agents may review distinct modules or risks. Give them
the shared rules, existing findings and check results, and the §5–6 ownership
constraint. Avoid assigning overlapping full audits solely by skill name.

### 3. Produce a Unified Report

After all three passes, produce one report: a
findings table by category and severity, up to 5 priorities, and an overall
assessment. Template and counting rules: [references/report.md](references/report.md).

### 4. Create Tasks for Findings

Bug tasks already exist from **find-code-bugs** (one per confirmed bug). Create a
`+codequality` task for every distinct, evidence-supported HIGH and MEDIUM design
or convention finding that is not already covered by a bug task. Advisory
observations do not create tasks or block audit closure.
When one problem recurs at many sites, file one task for the lever (a lint
rule, analyzer, or codemod that fixes and enforces it) instead of one per site.
Annotate every finding task, bug tasks included, with the fix procedure for its
kind (red first for bugs, pin behaviour before refactoring; the procedure itself
lives in **agent-task-management**).
Exact `ask add` format, fix procedures, and what to annotate:
[references/tasks.md](references/tasks.md#4-create-tasks-for-findings).

### 5. Create the Audit-Closure Gate Task (mandatory)

One `+audit` gate task that depends on every finding task and re-verifies the
codebase once they are done, including the hotspot scores compared with the
pass A baseline. Skip rules and the zero-findings path:
[references/tasks.md](references/tasks.md#5-create-the-audit-closure-gate-task-mandatory).

### 6. Create the Audit-Marker Tagging Task (mandatory last task)

One last `+audit` task, depending on the gate, that moves the `audit/<date>`
marker to the post-fix `HEAD` and pushes it. Annotations it needs:
[references/tasks.md](references/tasks.md#6-create-the-audit-marker-tagging-task-mandatory-last-task).

§5–6 are the sole owners of the gate and tagging task when this skill is driving;
do not create them from **agent-task-management**'s "Audit task batches" section.
