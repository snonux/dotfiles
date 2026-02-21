# Annotate / update task

Use with `00-context.md`. Project name and global rules apply. Only annotate, modify, or delete tasks that have both `project:<name>` and the `+agent` tag (use task IDs from `project:<name> +agent` filtered lists, or verify the task has `+agent` before acting).

## Reading task context

When working on a task, **always read the full context:** description, summary, and **all annotations**. Annotations often contain progress, challenges, and references to files or documents — use them for further reference.

View full task (including annotations):

```bash
task <id>
```

## Annotate a task

```bash
task <id> annotate "Note about progress or context"
```

While making progress, **add annotations** to reflect progress, challenges, or decisions. You may refer to files, documents, or other resources (paths, doc links, snippets) so the task history stays useful for later work and for the pre-completion review.

## Modify a task

```bash
task <id> modify +<tag>
task <id> modify depends:<id2>
task <id> modify priority:H
```

## Delete a task

```bash
task <id> delete
```

## Conventions

- Read description, summary, and all annotations when working on a task.
- Annotate with implementation notes, progress, challenges, and references to files or documents as you go.
