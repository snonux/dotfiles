# errcheck

[errcheck](https://github.com/kisielk/errcheck) finds silently ignored errors
in Go code. For every callable that is not in the excluded list, the returned
error must either be assigned to a variable or explicitly discarded with `_`.
This is a strong guardrail against the most common Go bug: dropping an error on
the floor.

errcheck does no further analysis on assigned errors (it will not complain if an
assigned `err` is later overwritten without being checked). For that depth of
analysis, also run [staticcheck](https://staticcheck.dev/).

## Install

```sh
go install github.com/kisielk/errcheck@latest
```

errcheck requires Go 1.25 or newer. The binary is placed in `$GOPATH/bin`
(default `~/go/bin`), so make sure that directory is on your `PATH`.

## Use

Check all packages beneath the current directory (the normal case for a repo):

```sh
errcheck ./...
```

Other invocations:

```sh
errcheck github.com/kisielk/errcheck/testdata   # a specific package path
errcheck all                                     # everything in GOPATH/GOROOT
```

Useful flags:

* `-blank` — also report errors assigned to the blank identifier (`_`), i.e.
  catch *explicitly* discarded errors you may want to revisit.
* `-asserts` — report ignored type-assertion results (`x, _ := i.(T)`).
* `-ignoretests` — skip `_test.go` files.
* `-ignoregenerated` — skip generated source.
* `-tags '<tag1> <tag2>'` — space-separated build tags, like `go build`.
* `-abspath` — print absolute paths to files with unchecked errors.
* `-exclude <file>` — path to a file listing functions to exclude (see below).
* `-excludeonly` — use only the supplied exclude file, disabling the built-in
  standard-library exclude list.

## Excluding functions

Pass `-exclude errcheck_excludes.txt` with one signature per line. The format is
`package.FunctionName` for functions and `(package.Receiver).MethodName` /
`(*package.Receiver).MethodName` for value/pointer-receiver methods. Empty lines
and `//` comments are ignored.

```
io.Copy(*bytes.Buffer)
io.Copy(os.Stdout)
os.ReadFile

// Sometimes we don't care if a HTTP request fails.
(*net/http.Client).Do
```

By default errcheck combines your list with an internal list of stdlib functions
that have an error return but are documented never to fail. Use `-excludeonly` to
disable that built-in list.

## AI-assisted tools and guardrails

Treat errcheck as a non-negotiable guardrail when an AI agent (or anyone) writes
or modifies Go code in this project:

* **Run it as part of verification**, alongside `go build ./...`, `go vet ./...`,
  and `gofmt -l .`, before claiming a change is complete:

  ```sh
  errcheck ./...
  ```

* **Treat findings as defects, not noise.** Every reported call must either check
  the error (wrap with `fmt.Errorf("...: %w", err)` per the error-handling
  conventions) or be *intentionally* discarded with an explicit `_ =` and, where
  it helps the reader, a short comment explaining why it is safe.

* **Do not silence it by deleting the check.** Prefer fixing the code. If a
  function genuinely never returns a meaningful error, add it to the project's
  `errcheck_excludes.txt` so the exception is reviewed and documented, rather than
  sprinkling blank assignments.

* **Wire it into automation.** Add an `errcheck ./...` step to the Magefile
  (e.g. a `Lint` target) and/or CI and a Git pre-commit hook so the guardrail
  runs without relying on the agent remembering to invoke it.

* **Honesty about what ran.** If errcheck is not installed or could not run, say
  so explicitly instead of implying the code was checked (see "Environment
  preflight and verification honesty" in the main skill).
