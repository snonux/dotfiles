# Annotate / update task

Use with `00-context.md`. Project name and global rules apply. Only annotate, modify, or delete tasks that have both `project:<name>` and the `+agent` tag. Use numeric IDs only within a single report; for any stored or shared reference (annotations, docs, handoffs), **refer to tasks by UUID** and prefer `uuid:<uuid>` selectors when running commands.

## Reading task context

When working on a task, **always read the full context:** description, summary, and **all annotations**. Annotations often contain progress, challenges, and references to files or documents — use them for further reference.

View full task (including annotations):

```bash
ask <id>
```

## Annotate a task

```bash
ask uuid:<uuid> annotate "Note about progress or context"
```

While making progress, **add annotations** to reflect progress, challenges, or decisions. You may refer to files, documents, or other resources (paths, doc links, snippets) so the task history stays useful for later work and for the pre-completion review.

Whenever you mention another task inside an annotation (for example, as a dependency or related work), include that other task’s **UUID**, not just its numeric ID.

## Modify a task

```bash
ask <id> modify +<tag>
ask <id> modify depends:<id2>
ask <id> modify priority:H
```

Use `uuid:<uuid>` in place of `<id>` when modifying tasks selected earlier or referenced from annotations or other docs, so changes are applied to the correct task even if IDs have been renumbered.

## Delete a task

```bash
ask <id> delete
```

## Conventions

- Read description, summary, and all annotations when working on a task.
- Annotate with implementation notes, progress, challenges, and references to files or documents as you go.
