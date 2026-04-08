# Annotate / update task

Use with `00-context.md`. Project name and global rules apply.

## Reading task context

When working on a task, **always read the full context:** description, summary, and **all annotations**. Annotations often contain progress, challenges, and references to files or documents — use them for further reference.

View full task (including annotations):

```bash
do info <id>
```

## Annotate a task

```bash
do annotate <id> "Note about progress or context"
```

While making progress, **add annotations** to reflect progress, challenges, or decisions. You may refer to files, documents, or other resources (paths, doc links, snippets) so the task history stays useful for later work and for the pre-completion review.

Whenever you mention another task inside an annotation (for example, as a dependency or related work), include that other task's alias ID.

## Modify a task

```bash
do modify <id> +<tag>
do dep add <id> <dep-id>
do modify <id> priority:H
```

Use the alias ID shown by `do list`, `do ready`, or `do info` when modifying tasks selected earlier or referenced from annotations or other docs.

## Delete a task

```bash
do delete <id>
```

## Conventions

- Read description, summary, and all annotations when working on a task.
- Annotate with implementation notes, progress, challenges, and references to files or documents as you go.
- Annotations should be detailed enough that a fresh-context agent can pick up work without needing to ask clarifying questions.
