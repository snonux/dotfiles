# Annotate / update task

Use with `00-cli.md` and `00-project-scope.md`.

## Reading task context

Read a task **in full once**, when you start on it: description and all
annotations.

```bash
ask info <id>
```

After that, re-read only what is new:

```bash
ask info <id> last:3
```

Do not re-run the same lookup unless the task may have changed. Session
history showed tasks being read four times at the median and up to 77 times,
with outputs of up to 60,000 characters each time.

## Annotate a task

```bash
ask annotate <id> "Note"
```

Annotate **milestones, not steps**: something a later reader needs that is
not in the code or the commit message. When one of these prefixes fits, use
it, so agents and people can find the annotation:

| Prefix | When |
|---|---|
| `Red first: <test> failed with <message>` | the test failed before the fix |
| `Decision: <choice> because <reason>` | you chose between real alternatives |
| `Needs human: <question>` | written for you by `ask park` |
| `Answer: <text>` | the human's answer to a parked question |
| `Handoff: <state>; next: <step>; uncommitted: <files>` | written by `ask stop <id> "..."` when stopping unfinished |
| `CRAP accepted: <function>: <reason>` | a complex function the reviewer should accept |
| `Committed in-scope: <files>. Left out-of-scope: <files>.` | the tree had unrelated changes |
| `Review skipped: <reason>` | the user asked for batch reviews or none |
| `Recovered: <what was reverted or kept>` | you resumed a stalled task |

Other skills add their own, such as `Agent workflow:` and `Also apply:` at
task creation and `Fix procedure:` on audit findings.

The delivery summary goes on `ask done <id> "<summary>"`. Progress that a
commit message already records does not need an annotation.

Whenever you mention another task inside an annotation, include that task's
alias ID. Refer to files by path.

## Modify a task

```bash
ask modify <id> +<tag>
ask dep add <id> <dep-id>
ask modify <id> priority:H
```

Use the alias ID shown by `ask list`, `ask ready`, or `ask info`.

## Delete a task

```bash
ask delete <id>
```

## Conventions

- Read the full task once; afterwards `ask info <id> last:3`.
- One annotation per milestone, with a prefix from the table.
- A fresh-context agent must be able to continue from the description, the
  annotations, and the commits without asking.
