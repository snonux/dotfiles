# Annotate / update task

Use with `00-context.md`. Project name and global rules apply.

## Reading task context

When working on a task, **always read the full context:** description, summary, and **all annotations**. Annotations often contain progress, challenges, and references to files or documents — use them for further reference.

View full task (including annotations):

```bash
ask info uuid:<uuid>
```

## Annotate a task

```bash
ask annotate uuid:<uuid> "Note about progress or context"
```

While making progress, **add annotations** to reflect progress, challenges, or decisions. You may refer to files, documents, or other resources (paths, doc links, snippets) so the task history stays useful for later work and for the pre-completion review.

Whenever you mention another task inside an annotation (for example, as a dependency or related work), include that other task's **UUID**.

## Modify a task

```bash
ask modify uuid:<uuid> +<tag>
ask modify uuid:<uuid> dep:add:<uuid2>
ask modify uuid:<uuid> priority:H
```

Use `uuid:<uuid>` when modifying tasks selected earlier or referenced from annotations or other docs, so changes are applied to the correct task even if IDs have been renumbered.

## Delete a task

```bash
ask delete uuid:<uuid>
```

## Conventions

- Read description, summary, and all annotations when working on a task.
- Annotate with implementation notes, progress, challenges, and references to files or documents as you go.
- Annotations should be detailed enough that a fresh-context agent can pick up work without needing to ask clarifying questions.
