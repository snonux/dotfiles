---
name: bash-best-practices
description: Bash coding style and conventions derived from foo.zone blog posts. Covers structure, safety, idioms, pipelines, redirection, and common pitfalls. Use when writing, reviewing, or refactoring Bash scripts.
---

# Bash Best Practices

Style and structural conventions drawn from the foo.zone Bash coding style guide and Bash Golf series. Apply when writing, reviewing, or refactoring Bash.

## When to Use

- Writing new Bash scripts or functions
- Reviewing or refactoring Bash code
- Aligning code with a strict, readable Bash style
- Resolving style questions (shebang, quoting, pipelines, error handling)

## Conventions Overview

Start every script with a portable shebang and strict-mode header:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Use soft-tabs (spaces), limit lines to ~80 characters, and quote variables whose content is unknown or external. Prefer Bash built-ins for light work and external tools (`sed`, `awk`, `grep`, `bc`) for heavy text processing.

Key idioms covered in detail below:

| Topic | File |
|-------|------|
| Shebang, strict mode, indentation, quoting, booleans, `declare`, `local -i` | [`reference/style.md`](reference/style.md) |
| Function naming, namespaces, `::`, private helpers (`_`), assign-then-shift, `case` dispatch | [`reference/functions.md`](reference/functions.md) |
| `set -e`, `set -o pipefail`, `PIPESTATUS`, arithmetic comparisons, restricted bash | [`reference/error-handling.md`](reference/error-handling.md) |
| Process substitution, `while read`, here-docs/here-strings, pipelines, `/dev/tcp`, `mapfile` | [`reference/io-patterns.md`](reference/io-patterns.md) |
| `eval` avoidance, namerefs, dynamic command arrays, atomic overwrite, throttling, `shellcheck` | [`reference/advanced.md`](reference/advanced.md) |

## Quick Checklist

- [ ] Shebang is `#!/usr/bin/env bash`
- [ ] Strict mode header (`set -euo pipefail`) at top of script
- [ ] Soft-tabs used, line length around 80
- [ ] `$(...)` used instead of backticks
- [ ] Variables quoted when content is unknown/external
- [ ] Internal helpers prefixed with `_`
- [ ] `case` used for multi-branch literal string matching
- [ ] Built-ins preferred for light work, external tools for heavy
- [ ] Booleans use `yes`/`no`
- [ ] `eval` avoided; `source` or process substitution used instead
- [ ] `set -e` enabled with localized `set +e` for expected failures
- [ ] `pipefail` used when pipelines must fail on any stage
- [ ] Numeric comparisons use `(( ))` or `-gt`/`-lt`/`-eq`
- [ ] Constants declared with `local -r` or `declare -r`
- [ ] Pipelines broken with backslash and leading `|`
- [ ] `FUNCNAME` used for logging when helpful
- [ ] `declare -n` used for indirection where possible
- [ ] `find -print0 | xargs -0` for file lists with spaces
- [ ] `while read` fed by process substitution (`< <(...)`) for variable survival
- [ ] `IFS='' read -r line` used when exact line preservation matters
- [ ] Here-strings (`<<<`) preferred over `echo | command` for single-line input
- [ ] Commands built dynamically in arrays when arguments are conditional
- [ ] Atomic file overwrite via temp + `diff -q` + `mv`
- [ ] Unit tests and `shellcheck` integrated
- [ ] `local -i` used for integer counters
- [ ] `mapfile` or `$(<file)` used instead of unnecessary `cat`
- [ ] Consistent style throughout the script/project
