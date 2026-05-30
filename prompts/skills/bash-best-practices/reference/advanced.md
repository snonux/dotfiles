# Advanced Bash Patterns

## Avoid `eval`

Avoid `eval`. Prefer sourcing files or process substitution to generate and source code dynamically.

```bash
# Good: source a file of declarations
source vars.source.sh

# Good: source generated code from a command
source <(./vars.sh)
```

## Namerefs (`declare -n`)

Use namerefs (Bash 4.3+) for cleaner indirection instead of `eval`.

```bash
set_value() {
    local -n ref="$1"
    ref="$2"
}
set_value my_var hello
```

You can also construct the target name dynamically:

```bash
make_var() {
    local idx=$1; shift
    local name="slot_$idx"
    printf -v "$name" '%s' "$*"
}

get_var() {
    local idx=$1
    local -n ref="slot_$idx"
    printf '%s\n' "$ref"
}
```

## Background-Job Throttling

When spawning parallel background jobs, cap them to the number of CPU cores and use `wait -n` to pause only until any slot frees up. This avoids process explosions.

```bash
local -r max_jobs=$(( $(nproc 2>/dev/null || echo 4) ))

for item in ...; do
    while (( $(jobs -rp | wc -l) >= max_jobs )); do
        wait -n
    done
    do_work "$item" &
done
wait
```

## Build Commands Dynamically with Arrays

When constructing commands conditionally, build an array to avoid word-splitting and empty-argument bugs.

```bash
local -a cmd=("$SOURCE_HIGHLIGHT" "--src-lang=$lang")
if [ -n "$SOURCE_HIGHLIGHT_CSS" ]; then
    cmd+=("--style-css-file=$SOURCE_HIGHLIGHT_CSS")
fi
"${cmd[@]}" <<< "$text"
```

## Atomic / Safe File Overwrite

Write to a temporary file, compare with `diff -q`, and `mv` only if content actually changed. This preserves mtime (helpful for downstream skip-logic) and avoids leaving partial files on interrupt.

```bash
safe_overwrite () {
    local -r tmp="$1"; shift
    local -r dest="$1"; shift

    if [[ -f "$dest" ]] && diff -q "$tmp" "$dest" >/dev/null 2>&1; then
        rm "$tmp"
    else
        mv "$tmp" "$dest"
    fi
}

# Usage:
echo 'new content' > "$dest.tmp"
safe_overwrite "$dest.tmp" "$dest"
```

## Self-Testing and ShellCheck

Include an `assert` module with helpers like `assert::equals`, `assert::contains`, `assert::not_empty`, and `assert::matches`. Run them as part of a `--test` target.

Also run `shellcheck` against your scripts as part of the test suite:

```bash
assert::shellcheck () {
    shellcheck \
        --norc \
        --external-sources \
        --check-sourced \
        --exclude=SC2155,SC2010,SC2154,SC1090,SC2012,SC2016,SC1091 \
        ./"$0"
}
```

If ShellCheck flags are unavoidable, document the specific `--exclude` reasons in comments.

## Random Numbers

Use the special `$RANDOM` variable for quick pseudo-random integers.

```bash
declare -i delay=$(( RANDOM % 60 ))
sleep $delay
```

## Environment Variables for Arguments

Pass required arguments via environment variables with `${VAR:?message}` for mandatory checks.

```bash
#!/usr/bin/env bash
declare -r USER=${USER:?Missing the username}
declare -r PASS=${PASS:?Missing the secret password for $USER}
```

## Atomic Locking with `mkdir`

Portable advisory locks can be emulated with `mkdir` because it is atomic:

```bash
lockdir=/tmp/myjob.lock
if mkdir "$lockdir" 2>/dev/null; then
    trap 'rmdir "$lockdir"' EXIT INT TERM
    # critical section
    do_work
else
    echo "Another instance is running" >&2
    exit 1
fi
```

## Smarter globs and faster find-exec

- Enable extended globs when useful: `shopt -s extglob`; then patterns like `!(tmp|cache)` work.
- Use `-exec ... {} +` to batch many paths in fewer process invocations:

```bash
find . -name '*.log' -exec gzip -9 {} +
```
