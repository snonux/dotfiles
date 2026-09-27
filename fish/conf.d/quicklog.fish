# Quicklog → taskwarrior import.
#
# Two sources feed the single line parser in this file:
#
#   * Garage S3 — the ~/scripts/quicklog-drain wrapper (run hourly by its
#     systemd timer, and by `ti` through taskwarrior::quicklog_import) drains
#     ql-*.md objects from the quicklog bucket and imports each note through
#     taskwarrior::quicklog_import_content before the remote object is
#     deleted. S3 notes never touch the local filesystem; the old
#     ~/Notes/Quicklog staging directory is retired.
#   * Local files — taskwarrior::quicklogger still scans $HOME/Notes and
#     $WORKTIME_DIR for ql-* files created directly on this machine.
#
# Note line format (one task per line):
#   [NUMBER] TAG[,TAG,...] description
# The brackets around NUMBER are grammar notation for an optional field, not
# literal characters: a due offset is a bare leading integer, e.g.
# `2 Home,groceries buy milk` (due in 2 days, project home, tag groceries).
# A capitalized first token of the tag field is a project name, the
# remaining comma-separated tokens are tags, and everything after the tag
# field is the task description.
#
# Retry semantics (both sources): a line that fails transiently (task add
# error) is never consumed — the S3 note stays in the bucket, the local file
# stays in place. A note is only deleted (or moved to /tmp) after every
# line was imported or skipped. Retries are idempotent: both consumers load
# the pending task descriptions once per run into __quicklog_pending and
# the line parser skips lines whose exact description is already pending, so
# re-drains after a crash, timeout or partial multi-line import cannot
# duplicate tasks. Trade-off: a note line whose description exactly matches
# an already-pending task is skipped — including one added moments ago by
# hand. Completed tasks never match, so recurring notes (same description
# every week) keep working. A note that fails permanently for an unknown
# cause is not detected as such: it stays queued, is retried and
# re-reported on stderr on every run until the cause is fixed or the note
# is removed manually (`quicklog-drain --keys` / `--delete KEY`).

# Imports a single Quicklog note line into taskwarrior via the shared
# _taskwarrior::add_task helper.
#
# Return codes distinguish permanent skips from transient failures so callers
# can decide whether the source note may be consumed:
#   0  task added
#   1  transient failure (task add failed) — keep the note for retry
#   2  permanent skip (blank/malformed line, implausible due offset) —
#      nothing to import; the line is consumed
#   3  duplicate skip — the exact description is already pending (see
#      __quicklog_pending); the line is consumed
#
# Dedup contract: when the caller has loaded __quicklog_pending (see
# taskwarrior::quicklog_import_content / taskwarrior::quicklogger), a line
# whose description matches a pending task is skipped (return 3), and each
# newly-added description is appended to that list so sibling lines of a
# multi-line note and crash-window re-drains cannot import the same
# description twice. The list is a global because fish function locals are
# not visible to (or mutable from) called functions — verified live.
function _taskwarrior::quicklog_import_line --description 'Import one Quicklog note line into taskwarrior'
    set -l line "$argv[1]"

    # Blank lines carry no task; not an error
    test -n "$line"; or return 2

    # Tolerate CRLF line endings from foreign editors: strip only a real
    # trailing carriage return. `string trim --chars '\r'` must not be used
    # here — in single quotes fish passes the two literal characters `\r`,
    # so it strips trailing 'r' or '\' from descriptions and leaves actual
    # CRs in place (verified live with fish 4.x).
    set line (string replace -r '\r+$' '' -- $line)

    # Tokenise by spaces, dropping empty tokens so doubled spaces cannot
    # shift the due/tag/description fields
    set -l tokens (string split ' ' -- "$line" | string match -r '.+')
    if not test (count $tokens) -gt 0
        return 2
    end

    # Optional first token: a plain integer means due in N days. Only a
    # sane range (0 ≤ N ≤ 10000, matching what `due:Nd` accepts usefully) is
    # accepted; anything else is a permanent skip so a pathological value
    # cannot make `task add` fail forever and poison the whole note into an
    # infinite retry.
    set -l idx 1
    set -l due ""
    if string match -qr '^\d+$' -- "$tokens[1]"
        if string match -qr '^([0-9]{1,4}|10000)$' -- "$tokens[1]"
            set due "$tokens[1]"
            set idx 2
        else
            echo "quicklog: malformed line (due offset outside 0..10000): $line" >&2
            return 2
        end
    end

    # A due offset with nothing after it cannot form a task
    if test $idx -gt (count $tokens)
        echo "quicklog: malformed line (no tag field): $line" >&2
        return 2
    end

    # Next token is the tag/project field; advance idx past it
    set -l tag_field "$tokens[$idx]"
    set idx (math "$idx + 1")

    # Split the tag field on commas first, then inspect the first element.
    # A capital first letter on the first element signals a project name;
    # any remaining comma-separated elements become plain tags.
    # e.g. "Foo,bar,baz" → project=foo, tags=(bar baz)
    # e.g. "bar,baz"     → project="",  tags=(bar baz)
    set -l tag_parts (string split ',' -- "$tag_field")
    set -l project ""
    set -l tags
    if string match -qr '^[A-Z]' -- "$tag_parts[1]"
        set project (string lower -- "$tag_parts[1]")
        test (count $tag_parts) -gt 1; and set tags (string lower -- $tag_parts[2..-1])
    else
        set tags (string lower -- $tag_parts)
    end

    # Drop empty tag tokens (e.g. "Foo,,bar") so they cannot reach task add
    set -l clean_tags
    for tag in $tags
        test -n "$tag"; and set -a clean_tags "$tag"
    end

    # Everything from idx onward is the free-text description
    set -l description ""
    if test $idx -le (count $tokens)
        set description (string join ' ' -- $tokens[$idx..-1])
    end
    test -n "$description"; or begin
        echo "quicklog: malformed line (no description): $line" >&2
        return 2
    end

    # Idempotent retry: skip when this exact description is already pending
    if contains -- "$description" $__quicklog_pending
        echo "quicklog: skip, task already pending: $description" >&2
        return 3
    end

    # Build flag args for the helper, omitting empty optional fields
    set -l add_args
    test -n "$due"; and set -a add_args --due $due
    test -n "$project"; and set -a add_args --project $project
    for tag in $clean_tags
        set -a add_args --tag $tag
    end

    # The `--` before the description keeps text that looks like taskwarrior
    # syntax (leading '-', '+tag') from being parsed as modifiers, so a
    # leading-dash description cannot break argparse or task add and loop
    # the note forever (verified live with argparse and TW 3.4.2).
    if not _taskwarrior::add_task $add_args -- $description
        echo "quicklog: task add failed (kept for retry): $line" >&2
        return 1
    end

    # Remember the new description so later lines of the same note (and
    # crash-window re-drains, once the caller reloads) match it as a dup
    if set -q __quicklog_pending
        set -a __quicklog_pending "$description"
    end
    return 0
end

# Imports a Quicklog note's content (read from stdin, one line per task) into
# taskwarrior using the shared line parser. This is the consumer side of the
# quicklog-drain S3 protocol: the script pipes each note's content here and
# deletes the remote object only when this returns 0.
#
# Pending descriptions are loaded once per note (not per line) and shared
# with the parser through __quicklog_pending, making retries idempotent:
# a re-imported note skips lines that are already pending. See the parser's
# dedup contract for the trade-off (exact-description match against pending
# tasks only).
#
# Returns 0 when every line was imported or skipped (duplicate/malformed
# lines are consumed), 1 when any line failed transiently — the caller must
# then keep the source note for retry.
function taskwarrior::quicklog_import_content --description 'Import Quicklog note content from stdin into taskwarrior'
    set -g __quicklog_pending (task status:pending export | jq -r '.[].description')
    set -l failed 0
    while read -l line
        _taskwarrior::quicklog_import_line "$line"
        switch $status
            case 0
                # imported
            case 2
                # malformed/blank: already warned; line is consumed
            case 3
                # duplicate of an already-pending task; line is consumed
            case 1
                # transient failure: keep the note for retry
                set failed 1
            case '*'
                # Unexpected status (a fish builtin error surfaced as the
                # function's return code): fail safe and keep the note for
                # retry rather than ack it as consumed and lose lines.
                echo "quicklog: unexpected import status $status (kept for retry): $line" >&2
                set failed 1
        end
    end
    set -e __quicklog_pending
    return $failed
end

# Scans local notes directories for quick-log files (ql-*) created directly on
# this machine and imports each line through the same shared parser as the S3
# pipeline. Pending descriptions are loaded once per scan (see the parser's
# dedup contract) so a partially processed file is not imported twice.
#
# Files whose import fails transiently (a task add error) stay in place for
# the next scan; fully processed files are moved to /tmp. Returns 0 when
# every file was consumed, 1 when at least one file was kept for retry.
function taskwarrior::quicklogger --description 'Import locally created Quicklog files into taskwarrior'
    set -l notes_dirs "$HOME/Notes"
    if set -q WORKTIME_DIR
        set -a notes_dirs "$WORKTIME_DIR"
    end

    set -g __quicklog_pending (task status:pending export | jq -r '.[].description')
    set -l any_kept 0

    for dir in $notes_dirs
        # Skip directories that don't exist on this machine
        if not test -d "$dir"
            continue
        end

        # -L follows symlinks (~/Notes is a symlink to the Syncthing vault)
        # -maxdepth 1 keeps the search non-recursive
        for ql_file in (find -L "$dir" -maxdepth 1 -name 'ql-*' -type f)
            set -l keep 0
            while read -l line
                _taskwarrior::quicklog_import_line "$line"
                switch $status
                    case 0
                        # imported
                    case 2
                        # malformed/blank: already warned; line is consumed
                    case 3
                        # duplicate of an already-pending task; line is consumed
                    case 1
                        # transient failure: leave the file for the next scan
                        set keep 1
                    case '*'
                        # Unexpected status: fail safe, keep the file
                        echo "quicklogger: unexpected import status $status (kept for retry): $line" >&2
                        set keep 1
                end
            end <$ql_file
            if test $keep -eq 0
                # Restrict permissions before moving so the file is not
                # world-readable in /tmp
                chmod 600 $ql_file
                mv $ql_file /tmp/
            else
                set any_kept 1
                echo "quicklogger: kept $ql_file for retry (task add failed)" >&2
            end
        end
    end

    set -e __quicklog_pending
    return $any_kept
end

# Direct S3 → taskwarrior import: the ~/scripts/quicklog-drain wrapper drains
# the Garage quicklog bucket and imports every note without staging ql-*.md
# files on disk. It owns credentials, locking (timer vs. manual run) and the
# delete-only-after-import flow; this function is the `ti`/interactive entry
# point. Flags pass through (--dry-run, --limit N, --only KEYS, --dest DIR).
#
# NOTE deploy ordering: fish conf.d is deployed as a live symlink, so this
# file's functions apply immediately, but ~/scripts/quicklog-drain and the
# systemd units are gonf copies that only update via `./gonf.sh home` —
# deploy them together (see the wrapper header for the mixed-state hazards).
function taskwarrior::quicklog_import --description 'Import Garage quicklog notes directly into taskwarrior'
    set -l script "$HOME/scripts/quicklog-drain"

    if not test -x "$script"
        echo "taskwarrior::quicklog_import: missing $script (deploy dotfiles via gonf)" >&2
        return 1
    end

    "$script" $argv
end