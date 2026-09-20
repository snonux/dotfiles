# Closing a non-ACQ audit task batch

Read this after `1-create-task.md` only when you are the top-level
orchestrator that has finished filing tasks from a code audit. Do not use it
when a sub-skill or sub-agent is merely filing findings, or when
`auditing-code-quality` is driving the run; ACQ owns its closure gate and
tagging task.

For a non-ACQ audit that created `+bugfix` and/or `+codequality` finding tasks
(for example, from `find-code-bugs`, `solid-principles`,
`beyond-solid-principles`, or `go-best-practices`), create the following two
`+audit` tasks only after all finding tasks have been created. If no finding
tasks were created, create neither task.

## 1. Closure gate

Create one `+audit` task with every finding ID as a dependency. Use the exact
`+audit` tag, never a hyphenated variant. Do not set a priority: its dependency
list is the gate.

```bash
ask add +audit depends:<id1>,<id2>,...,<idN> "Finalize <project> code-quality audit: verify all audit-driven fixes landed, re-run guardrails (build/vet/test -race/gofmt -l/linters), close out verification"
```

Annotate it with the dependent IDs, the guardrails to rerun when it becomes
ready, and the instruction to confirm every dependent is done with `ask list`
before marking the gate done. For Go, use `go build ./...`, `go vet ./...`,
`go test -race ./...`, `gofmt -l .`, and `errcheck ./...`; adapt the commands
to the language. This is a verification gate only. It does not own the
`audit/<date>` git marker.

## 2. Tagging task

After creating the closure gate, create one final `+audit` task that depends
only on the gate alias ID:

```bash
ask add +audit depends:<gate-id> "Tag <project> that the code-quality audit is done: follow the audit-tagging skill to move the audit/<date> marker to the post-fix HEAD and push the end marker"
```

Annotate it with the exact `$START_TAG` name, including any `-N` suffix, and
instructions to load `audit-tagging` for the end-marker and push steps. Do not
paste `git tag` or `git push` commands into the annotation. If no start tag is
already in context for an ATM-only batch, use `audit-tagging` to create one at
this point and record its exact name; move and push it when the tagging task is
ready.
