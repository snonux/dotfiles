# Bash Style and Structure

## Shebang

Use `#!/usr/bin/env bash` for portability across Unix-like systems (not all have Bash at `/bin/bash`).

```bash
#!/usr/bin/env bash
```

## Strict Mode Header

Start every script with a strict-mode header. Combine `set -e`, `set -u`, and `set -o pipefail` so the script aborts on unexpected errors, unset variables, and pipeline failures.

```bash
set -euo pipefail
```

Some projects also add `set -f` (disable pathname expansion). Choose the combination appropriate for your script and apply it consistently.

If a script sources configuration files that may leave variables unset, initialize those variables to empty strings **before** enabling `set -u`:

```bash
test -z "$CONFIG_FILE_PATH" && CONFIG_FILE_PATH=''
test -z "$LOG_VERBOSE" && LOG_VERBOSE=''
set -euo pipefail
```

Alternatively, access potentially-unset optional variables with `${VAR:-}` or `${VAR:-default}`:

```bash
if [ -f "${HTML_JS_SCRIPT:-}" ]; then
    cp "$HTML_JS_SCRIPT" "$dest"
fi
```

## Command Substitution

Always use `$(...)` instead of backticks. It nests cleanly, is easier to read, and avoids quoting issues.

```bash
# Good
date_stamp=$(date +%Y%m%d)

# Bad (backticks)
date_stamp=`date +%Y%m%d`
```

## Indentation and Line Length

- **Indentation**: Use soft-tabs (spaces), not tabs. Two or four spaces are both acceptable; pick one and be consistent within the project.
- **Line length**: Limit to 80 characters where practical. It encourages smaller functions and is friendlier on small screens.

## Breaking Long Pipelines

Break long pipelines with a backslash before the pipe and a leading pipe on continuation lines. The leading pipe is a visual eye-catcher.

```bash
# Good
command1 \
  | command2 \
  | command3 \
  | command4
```

## Quoting Variables

- Quote variables when the value comes from external input, may contain whitespace, or is unknown.
- In small scripts with simple bare-word values, unquoted variables are acceptable for readability.
- In large or shared scripts, quote consistently to avoid accidents and keep ShellCheck happy.
- Use `${var}` braces only when required (adjacent text, arrays) or when they improve clarity.

```bash
# Unknown/external input: quote
echo "${greeting} ${name}!"

# Simple bare words: optional but be consistent
local -r greeting=Hello
local -r name=Paul
echo "$greeting $name!"

# Braces required
echo "foo${FOO}baz"
```

## Boolean Style

Bash has no native boolean. Use the string literals `yes` and `no`.

```bash
declare -r SUGAR_FREE=yes
declare -r I_NEED_THE_BUZZ=no
```

## Multi-line Comments

Use a here-doc redirected to the null command for multi-line comments.

```bash
: <<COMMENT
This is a multi-line comment.
COMMENT
```

## `declare` Modifiers

Use `declare` modifiers for clarity and safety:

- `-r` for read-only (constants)
- `-i` for integers
- `-a` for indexed arrays
- `-A` for associative arrays (Bash 4+)

```bash
declare -r MAX_RETRIES=3
declare -i counter=0
declare -a fruits=(apple banana cherry)
```

## `local -i` for Integer Variables

Declare integer locals with `local -i` so arithmetic is cleaner and safer.

```bash
some_function () {
    local -i num_files=0
    num_files=$(( num_files + 1 ))
    # Alternatively:
    (( num_files++ ))
}
```
