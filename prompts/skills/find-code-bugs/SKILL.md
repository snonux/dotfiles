---
name: find-code-bugs
description: "Systematically hunts defects in code (logic, concurrency, errors, APIs, security) and records each confirmed issue as a separate agent task via the `ask` CLI. Use when asked to find bugs, defects, regressions, suspicious code, or to run a bug sweep; triggers on: find bugs, bug hunt, defect scan, code bugs."
---

# Find Code Bugs

## When to Use

- User wants a **bug sweep**, **defect review**, or **find bugs** in a codebase or change set.
- Triggers: *find bugs*, *bug hunt*, *defects*, *suspicious code*, *what could break*.

## Prerequisites

- **Git project**: `ask` tasks are scoped to the current repository. If there is no git root, report that and skip task creation (still list findings in the reply).
- **Task creation**: For each distinct bug, follow **agent-task-management** — load [the CLI contract](../agent-task-management/references/00-cli.md), [the project-scope rules](../agent-task-management/references/00-project-scope.md), then [the task-creation rules](../agent-task-management/references/1-create-task.md) before running `ask`, or obey the condensed rules below. For a standalone/top-level bug sweep that creates finding tasks, load [the audit-batch closure rules](../agent-task-management/references/1a-audit-task-batches.md) after all finding tasks have been created. Do not use those closure rules when `auditing-code-quality` is driving the run; that skill owns its closure gate and tagging task.

## Instructions

### 1. Scope and inputs

- Clarify scope if missing: paths, PR/diff, language, or “whole module X”.
- Prefer reading real sources and running project checks (tests, linters, typecheck) when available.

### 2. Hunt method (pick what fits the stack)

Work in this order unless the user specifies otherwise:

1. **Fast signals**: failing tests, compiler/type errors, linter output, obvious control-flow mistakes.
2. **Correctness**: null/nil handling, off-by-one, wrong operators, missing error checks, incorrect defaults, integer overflow, timezone/UTC mistakes.
3. **Concurrency / resources**: races, locks, goroutines/channels (Go), async leaks, unclosed handles, connection pools.
4. **APIs and boundaries**: validation, authz, injection (SQL/XSS/command), deserialization, file path traversal.
5. **Observability**: misleading logs, swallowed errors, metrics that lie.

Only report something as a **bug** if you can point to **symptom or failure mode** (wrong output, crash, security gap, data loss) and **location** (file + symbol or line range). Separate **spec uncertainty** from **code defect**; file the latter as tasks, note the former in prose.

### 3. One task per bug (mandatory)

For **each** distinct confirmed bug:

1. **Create task** (valid `ask` syntax only — no natural language to `ask`):

   ```bash
   ask add +bugfix "Fix: <short title> — <one-line impact>"
   ```

   Use an extra tag if useful (`+security`, `+cli`, etc.) per project conventions in agent-task-management.

2. **Capture the printed alias ID** from `created task <id>`.

3. **Annotate** with everything needed for a **fresh-context** fixer: file paths, line/symbol references, repro steps or failing test name, expected vs actual. Follow the annotation template in [the task-creation rules](../agent-task-management/references/1-create-task.md) (agent workflow reminder + language best-practices skills).

4. If bugs **depend** on each other, create tasks with `depends:<id>,...` on `ask add` as documented there.

Do **not** batch multiple unrelated bugs into one task.

### 3a. Close a standalone/top-level bug-sweep batch (mandatory)

If this is a standalone or top-level `find-code-bugs` run and it created one or
more finding tasks, load and follow [the audit-batch closure rules](../agent-task-management/references/1a-audit-task-batches.md) **after all finding tasks exist**. Those rules require a `+audit` closure gate that depends on every finding task, followed by a `+audit` tagging task that depends on the gate.

Do not create those two tasks when no findings were filed. Do not apply this
step when `auditing-code-quality` is driving the run: ACQ owns the closure gate
and tagging task.

### 4. Report back

In the user-facing summary:

- Table or bullet list: **bug summary**, **severity** (critical / high / medium / low), **location**, **`ask` task id** (or “not created — not a git repo”).
- Optional: suggested test to lock the fix.

## Examples

**Single bug → one task**

```bash
ask add +bugfix "Fix: nil deref in UserLoader when cache miss — panic on cold start"
# then: ask annotate <id> "..."
```

**Two independent bugs → two tasks**

Run `ask add` twice; annotate each with its own file/line context.

## Related skills

- [**agent-task-management**](../agent-task-management/SKILL.md): authoritative `ask` rules, tags, dependencies, annotations, and audit-batch closure.
