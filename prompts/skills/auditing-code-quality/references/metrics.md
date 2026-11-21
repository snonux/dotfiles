# Auditing Code Quality: metrics, dead code and test quality

Workflow §2A and §2C of [`SKILL.md`](../SKILL.md), and the baseline that the
§5 closure gate re-checks. The idea comes from Uncle Bob's
[ub-mode](https://github.com/unclebob/ub-mode), which uses CRAP, duplication
and mutation tools as hard gates while writing code. This audit uses the same
measurements differently, and the difference matters:

- **During review** a score decides *where to look first*. A finding still
  needs the evidence required by
  [the shared finding rules](report.md#shared-finding-rules). A high score is
  never a finding by itself.
- **At the closure gate** the scores are a verification signal: fixed code
  should score no worse than the baseline did.

Record every command, its scope, and what could not run, as for any check in
pass A. If a tool is not installed and cannot be installed, say so and
continue without it.

## 1. Hotspot ranking (pass A)

**CRAP** (Change Risk Anti-Patterns) combines complexity and test coverage:
`CRAP = cc² × (1 − coverage)³ + cc`. A complex function with no tests scores
high; one that is simple or well tested scores low. That makes it a better
lead than function length or complexity alone.

For Go, use the bundled stdlib-only tool (no gocyclo needed):

```bash
go test -coverprofile="$SCRATCH/cover.out" ./...   # failing packages still write blocks for the rest
go -C <this-skill>/scripts/gocrap run . -root "$PWD" -cover "$SCRATCH/cover.out" -top 20
```

It prints `CRAP  CC  COV%  LOCATION  FUNC` as tab-separated values, skipping
`_test.go`, generated files, `vendor/` and `testdata/`. Without `-cover`, or
for functions missing from the profile, COV% is `-` and the score assumes no
coverage. Run it from a module root; repeat it per module in a multi-module
repo. `-changed <rev>` keeps only functions whose lines differ from that git
revision (untracked files are not included). Task reviews use it to check the
code a change touched; see "Change risk of touched functions" in
[agent-task-management's completion reference](../../agent-task-management/references/3-complete-task.md).

For duplication in Go, `dupl -t 100 .` (`go install github.com/mibk/dupl@latest`)
lists duplicated token sequences. For other languages, `lizard` (cyclomatic
complexity per function, many languages) and `jscpd` (duplication) are
reasonable equivalents. Combine lizard's complexity with the coverage report
by hand when it is cheap to do so; otherwise rank by complexity and state that
coverage was not factored in.

How to use the ranking:

- Start passes B and C at the top of the list, and read every function scoring
  **30 or more** (Savoia's original "crappy" threshold). ub-mode's target of
  below 10 is a design goal for new code, not an audit threshold.
- Check duplicates against [DRY](../../beyond-solid-principles/references/dry.md):
  only duplicated *knowledge* (one rule that must change in two places) can be
  a finding. Code that looks alike but encodes different concepts is fine.
- Put the top 10 rows, plus any row a finding refers to, in the report's
  **Hotspots** table ([report.md](report.md#hotspots)).

## 2. Dead code (pass A)

Unreachable code is maintenance cost with no benefit, and removing it is the
cheapest remedy there is. For Go:

```bash
staticcheck ./...        # includes U1000 (unused); go install honnef.co/go/tools/cmd/staticcheck@latest
deadcode -test ./...     # unreachable from main and tests; go install golang.org/x/tools/cmd/deadcode@latest
```

Before reporting, confirm the code is not reached through reflection,
`go:linkname`, build tags not in the default build, plugins, or an exported API
that other modules use. Dead code confirmed this way is a LOW finding. Raise
it to MEDIUM when it actively misleads, such as a second implementation of
logic that callers might pick by mistake.

## 3. Test quality (pass C)

Coverage only shows that code ran under test, not that a test would notice it
breaking. Review the tests around the top hotspots and the code behind each
finding with two checks:

- **Return-nothing check:** would this test still pass if every function it
  exercises returned zero values or did nothing? Then it checks nothing. Tests
  that assert only "no error" or mirror the implementation step by step fail
  this check too.
- **Mutation testing**, time-boxed to the two or three riskiest packages from
  the hotspot list. For Go, use gremlins
  (`go install github.com/go-gremlins/gremlins/cmd/gremlins@latest`; run
  `gremlins unleash` from the module root and check `gremlins unleash --help`
  for how to limit it to one package). It reports each mutant as KILLED,
  LIVED, or NOT COVERED. Mutation runs are slow and need only the pushed repo,
  so a cloud sub-agent can run them.

A surviving (LIVED) or uncovered mutant in code whose failure matters counts
as evidence under the shared rules: the consequence is that a regression in
that behaviour ships undetected. File it as a MEDIUM design finding naming the
behaviour that is not pinned down, not one finding per mutant. Surviving
mutants in logging, formatting, or trivial getters are advisory at most.
Mutants that cannot change observable behaviour (equivalent mutants) are not
findings.

## 4. Baseline and closure-gate comparison

Annotate the §5 gate task with the baseline so the comparison works days later
in a fresh context ([tasks.md](tasks.md#5-create-the-audit-closure-gate-task-mandatory)):

- the exact hotspot commands from §1, and
- the baseline rows: the top 10, plus every function that a finding task targets.

When the gate becomes READY, re-run the same commands and match rows by file
and function name (line numbers move). Expect each targeted function's score
to have dropped, or the finding's fix to explain why it did not, for example
when the fix was in a caller. A targeted function that scores higher than its
baseline, or a function new to the top 10 at 30 or more that the fixes
introduced, needs either a one-line justification in the gate annotation or a
follow-up task before the gate is marked done.
