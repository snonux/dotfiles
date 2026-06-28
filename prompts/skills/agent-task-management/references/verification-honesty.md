# Verification Honesty

General discipline for claiming that work is verified. This is task-lifecycle
policy, not specific to any language — language skills (e.g. `go-best-practices`)
link here and add only their toolchain-specific concrete actions.

The core rule: **be explicit about what actually ran.** A *missing or incomplete*
toolchain (not slow tests) is the most common cause of false "verified" claims.

## Before claiming any verification

Confirm the local toolchain can actually build and run the relevant tests.

- **Preflight first.** Verify the build/test path works before trusting it —
  run the project's build command, confirm required native headers / CGO
  dependencies are present, and confirm required external tools are on `PATH`.
  If preflight fails, do not claim the project builds.
- **Run the smallest verifying subset that DOES work.** When part of the
  toolchain is missing, still verify what you can — linters, formatters,
  `build` on the packages that do not need the missing headers, and the unit
  tests that do not require the missing tool. Use build tags or explicit
  package paths to skip the unbuildable parts.
- **Annotate the blocker explicitly.** Record what is missing and the impact
  with `ask annotate <id> "<note>"` — name the missing header/tool, what you
  verified, and what you could not.
- **Never claim full verification when it did not run.** State precisely what
  was and was not verified (e.g. "vet + gofmt clean; package X not built —
  header Y missing; tests for X not run"). Do not imply a green build or
  passing tests that never executed.

## Long-running / timeout-exceeding test suites

Distinct from a *missing* toolchain: here the toolchain works, but the full
suite is too slow to finish within the command timeout. Run a focused subset
rather than nothing, and be explicit that you did so.

- **Run a representative subset within the timeout.** Scope to the package(s)
  the change touches and skip the slow target. Prefer a "short" flag (have slow
  tests honor it), build tags, or a run-pattern filter to exclude expensive
  integration/E2E tests; run the unit subset when the full integration suite
  cannot complete.
- **Annotate the intentional skip.** Record with `ask annotate <id> "<note>"`
  that the full suite was *intentionally* skipped, why (exceeds timeout, not a
  failure), which subset ran, and the result — e.g. "integration suite skipped
  (>30m, timeout); ran unit subset for package X → pass".
- **Acceptance implications.** A focused subset is NOT full verification. Be
  explicit about residual risk — untested integration paths, packages not
  touched — so the reviewer/orchestrator can decide whether to accept or run
  the full suite out-of-band. Never imply the full suite passed when it never ran.

## Summary checklist

- [ ] Toolchain preflight passed before claiming a build
- [ ] The smallest verifying subset that works was run
- [ ] Missing headers/tools named explicitly in an `ask annotate` note
- [ ] No implication that unrun tests passed
- [ ] Slow suites: subset run, skip annotated, residual risk stated