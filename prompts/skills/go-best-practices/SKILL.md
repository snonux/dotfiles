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

### Environment preflight and verification honesty

Before claiming any verification, confirm the local toolchain can actually build and run the relevant tests. A *missing or incomplete* toolchain (not slow tests) is common: e.g. CGO headers absent (`bpf/bpf.h` for eBPF code), or external tools not installed (`flutter`/`dart` for a companion app).

* **Preflight first:** Verify the build/test path works before trusting it—run `go build ./...`, confirm required CGO headers are present, and confirm required external tools are on `PATH`. If preflight fails, do not claim the project builds.
* **Run the smallest verifying subset that DOES work:** When part of the toolchain is missing, still verify what you can—`go vet ./...`, `gofmt -l .`, `go build` on the packages that do not need the missing headers, and the unit tests that do not require the missing tool. Use build tags or explicit package paths to skip the unbuildable parts.
* **Annotate the blocker explicitly:** Record what is missing and the impact with `ask annotate <id> "<note>"`—name the missing header/tool, what you verified, and what you could not.
* **Never claim full verification when it did not run:** State precisely what was and was not verified (e.g. "vet + gofmt clean; `./internal/bpf` not built—`bpf/bpf.h` missing; eBPF tests not run"). Do not imply a green build or passing tests that never executed.

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
