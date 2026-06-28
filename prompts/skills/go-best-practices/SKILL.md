---
name: go-best-practices
description: Enforce Go best practices for project structure, style, and conventions in the current codebase.
---

# Go Best Practices

Enforce Go project structure, style, and conventions in the current codebase.

## When to Use

- Use this skill when working on a Go project to ensure the code follows the established best practices.
- Use this skill to review or refactor existing Go code for compliance.

## Instructions

When writing or modifying Go code in the current project, follow all of the conventions below.

### Semantics and receivers

* Prefer value semantics over pointer semantics if feasible
* Have either pointer or value receivers, not both, for methods on a type

### File layout and order

* Constants, global variables, and type definitions always at the top of the file, before functions and methods
* Public functions and methods before private ones in the file
* Constructors must be the first functions in a file (before all methods), immediately after type definitions—even if non-public

### Project structure

* Binary is in `./cmd/NAME/main.go`
* Main file should be fairly small: argument/flags parsing and calling functions from the internal package only
* Internal code is in `./internal`
* Version of the app is a constant in `./internal/version.go`; a `-version` flag in main.go prints it out

### Dependencies and I/O

* Avoid package-level variables unless absolutely necessary; prefer dependency injection
* Use `context.Context` as the first parameter for functions that may block, perform I/O, or be canceled
* Use `defer` to close resources (files, connections) as soon as they are opened

### Errors and interfaces

* Use error wrapping (`fmt.Errorf` with `%w`) to provide context for errors
* Never silently ignore returned errors—check them, or discard them explicitly with `_ =`. Run `errcheck ./...` to catch silently ignored errors (install and usage: `references/errcheck.md`)
* Prefer explicit interface satisfaction for public types: `var _ MyInterface = (*MyType)(nil)`
* Keep interfaces small and focused; accept interfaces, return concrete types

### Formatting and documentation

* Use `gofmt` and `goimports` to enforce formatting and import order
* Document all exported identifiers with comments starting with the identifier's name
* Avoid stutter in package and type names (e.g. `foo.FooType` → `foo.Type`)

### Naming and constants

* Short variable names for short-lived variables, longer names for longer-lived ones
* Use `iota` for related constant values

### Testing and robustness

* Use table-driven tests for unit testing
* Aim for unit test coverage of 60%
* Avoid `panic` except for truly unrecoverable errors (e.g. programmer errors)
* Avoid large functions; split into smaller, focused helpers (max ~50 lines per function)
* Avoid code duplication where reasonable

### AI-assisted tools and guardrails

When writing or modifying Go code (especially with an AI agent), run static-analysis guardrails as part of verification, not just `go build`/`go test`.

* **errcheck:** Run `errcheck ./...` to catch silently ignored errors—one of the most common Go bugs. Treat findings as defects: check the error (wrap with `%w`) or discard it explicitly with `_ =`. Do not silence it by deleting the check. See `references/errcheck.md` for install instructions, flags, exclude files, and how to wire it into the Magefile / CI / pre-commit hooks.
* Be honest about what actually ran: if errcheck (or any tool) is not installed or could not run, say so rather than implying the code was checked.

### Verification honesty (Go specifics)

The general discipline — preflight the toolchain, run the smallest verifying
subset that works, annotate blockers with `ask annotate`, never claim full
verification that did not run, and the long-running-suite subset rule — lives in
the [`agent-task-management` skill](../agent-task-management/references/verification-honesty.md).
Follow it for any Go verification. The Go-specific concrete actions:

* **Preflight:** `go build ./...`; confirm CGO headers are present (e.g.
  `bpf/bpf.h` for eBPF code) and external tools are on `PATH` (e.g.
  `flutter`/`dart` for a companion app).
* **Smallest verifying subset when part of the toolchain is missing:**
  `go vet ./...`, `gofmt -l .`, `go build` on the packages that do not need the
  missing headers, and the unit tests that do not require the missing tool.
  Use build tags or explicit package paths to skip the unbuildable parts.
* **Slow suite within timeout:** `go test ./internal/foo/... -run <Pattern>
  -short`. Prefer `-short` (have slow tests honor `testing.Short()`), build
  tags, or `-run` to exclude expensive integration/E2E tests. Example: `mage
  integrationTest` runs > 30m; scope to the changed package and skip that
  target.

### Build system

Use Mage (Magefile.go) for build, install and test targets (and deinstall/uninstall when needed).

#### Magefile.go structure

* **Build tag and package:** `//go:build mage` at top; `package main`. Brief comment describing the project and that targets follow the same style as other projects (e.g. hexai) if applicable.
* **Imports:** `github.com/magefile/mage/mg`, `github.com/magefile/mage/sh`; plus stdlib as needed (`fmt`, `os`, `path/filepath`).
* **Constants:** Define `binaryName` (or equivalent) for the built binary.
* **Default target:** `Default()` calls `mg.Deps(Build)` so `mage` with no args builds.
* **Build:** `Build()` runs `go build -o <binaryName> ./cmd/<name>` via `sh.RunV`.
* **Test:** `Test()` runs `go test ./...` via `sh.RunV`.
* **Install:** `Install()` depends on `Build` via `mg.Deps(Build)`; resolves GOPATH (default `~/go` when unset); ensures `GOPATH/bin` exists with `os.MkdirAll`; copies the binary there with `cp -v`. Use `fmt.Errorf` with `%w` for errors (e.g. resolving home).
* **Other targets:** Add Uninstall/Deinstall or custom targets as needed; keep the same style (mg.Deps for ordering, sh.RunV for external commands).
