set -g TASKWARRIOR_MAX_PENDING_RANDOM_TASKS 10

function taskwarrior::due_count
    set -l due_count (task status:pending due.before:now count)

    if test $due_count -gt 0
        echo "There are $due_count tasks due!"
    end
end

function taskwarrior::add::track
    if test (count $argv) -gt 0
        task add priority:L +personal +track $argv
    else
        tasksamurai +track
    end
end

function _taskwarrior::set_import_export_tags
    if test (uname) = Darwin
        set -gx TASK_IMPORT_TAG work
        set -gx TASK_EXPORT_TAG personal
    else
        set -gx TASK_IMPORT_TAG personal
        set -gx TASK_EXPORT_TAG work
    end
end

function taskwarrior::is_personal_device
    test (uname) = Linux
end

function taskwarrior::random_count
    task status:pending +random -work count
end

function taskwarrior::random_slots_left
    set -l pending (taskwarrior::random_count)
    math $TASKWARRIOR_MAX_PENDING_RANDOM_TASKS - $pending
end

# Normalizes a comma-separated list of tags by trimming whitespace and printing each tag on a new line.
function taskwarrior::normalize_tags
    set -l tags_csv "$argv[1]"
    set -l normalized
    for tag in (string split ',' -- "$tags_csv")
        set -l trimmed (string trim -- "$tag")
        if test -n "$trimmed"
            set -a normalized "$trimmed"
        end
    end
    printf '%s\n' $normalized
end

function taskwarrior::export::bd
    if test -d ~/Notes/Bulgarian
        # Export bulgarian dumi
        set -l outfile ~/Notes/Bulgarian/bd-(date +%s).txt
        task +bd status:pending export | jq -r '.[].description' >$outfile
        # Guard against "No tasks specified." when there is nothing to delete
        test (task +bd status:pending count) -gt 0; and yes | task +bd status:pending delete
        cat ~/Notes/Bulgarian/bd-*.txt | sort -u >~/Notes/Bulgarian/compact-(date +%s).tmp && rm ~/Notes/Bulgarian/bd-*.txt
        sort -u ~/Notes/Bulgarian/compact-*.tmp >~/Notes/Bulgarian/bd-compacted.txt && rm ~/Notes/Bulgarian/compact-*.tmp
    end
end

function taskwarrior::export::maybe
    set -l maybefile ~/Notes/random/Maybe.md
    if test -f $maybefile
        # Export all maybe project tags
        for tag in m may maybe
            task +$tag -random status:pending export | jq -r '.[].description' | sed 's/^/* /' >>$maybefile.tmp.1
            # Guard against "No tasks specified." when there is nothing to delete
            test (task +$tag -random status:pending count) -gt 0; and yes | task +$tag -random status:pending delete
        end
        grep -F '* ' $maybefile >>$maybefile.tmp.1

        echo "# Maybe (7)" >$maybefile.tmp.2
        echo '' >>$maybefile.tmp.2
        echo 'Thinks I maybe will do something about or maybe not' >>$maybefile.tmp.2
        echo '' >>$maybefile.tmp.2
        sort -u $maybefile.tmp.1 >>$maybefile.tmp.2 && mv $maybefile.tmp.2 $maybefile && rm $maybefile.tmp.1
    end
end

function taskwarrior::export
    _taskwarrior::set_import_export_tags
    set -l ts (date +%s)

    for task_status in pending completed
        set -l count (task +$TASK_EXPORT_TAG status:$task_status count)

        if test $count -eq 0
            continue
        end

        echo "Exporting $count $task_status tasks to $TASK_EXPORT_TAG"
        task +$TASK_EXPORT_TAG status:$task_status export >"$WORKTIME_DIR/tw-$TASK_EXPORT_TAG-export-$ts-$task_status.json"
        yes | task +$TASK_EXPORT_TAG status:$task_status delete
    end

    taskwarrior::export::bd
    taskwarrior::export::maybe
end

function taskwarrior::import
    _taskwarrior::set_import_export_tags

    find $WORKTIME_DIR -name "tw-$TASK_IMPORT_TAG-export-*.json" | while read -l import
        task import $import
        rm $import
    end

    find $WORKTIME_DIR -name "tw-(hostname)-export-*.json" | while read -l import
        task import $import
        rm $import
    end
end

function taskwarrior::cleanup
    # Delete only tasks completed over a week ago
    test (task +random status:completed end.before:today-7days count) -gt 0; and yes | task +random status:completed end.before:today-7days delete
    test (task +agent status:completed end.before:today-7days count) -gt 0; and yes | task +agent status:completed end.before:today-7days delete
end

function taskwarrior::unscheduled
    # _ids can emit a trailing empty line; skip empty values to avoid a no-filter modify
    for id in (task status:pending -unsched -nosched -meeting -track due: _ids)
        test -n "$id"; or continue
        echo "timeout 5s task modify $id due:(builtin random 0 30)d"
        timeout 5s task modify "$id" due:(builtin random 0 30)d
    end
end

# Adds a single taskwarrior task. Can be reused anywhere task creation is needed.
# Description is the required positional argument.
# Optional flags:
#   --due N        due in N days (passed as due:Nd to task)
#   --project NAME assign a project
#   --tag TAG      add a tag; repeat for multiple tags
function _taskwarrior::add_task
    argparse 'due=' 'project=' 'tag=+' -- $argv
    or return 1

    # Remaining positional arguments form the description (required)
    set -l description (string join ' ' -- $argv)
    test -n "$description"; or return 1

    # Build argument list for `task add`, only including flags that were provided
    set -l cmd_args
    test -n "$_flag_due"; and set -a cmd_args "due:$_flag_due"d
    test -n "$_flag_project"; and set -a cmd_args "project:$_flag_project"
    for tag in $_flag_tag
        set -a cmd_args "+$tag"
    end

    # Print the full command before executing it for transparency;
    # description is escaped so the output is unambiguous even with quotes or special chars
    echo "task add $cmd_args "(string escape -- $description)
    task add $cmd_args $description
end

# Scans all known notes directories for quick-log files (ql-*) and parses each
# line into its constituent task fields. Each line follows the format:
#   [NUMBER] TAG[,TAG,...] description
# where NUMBER is an optional due offset in days, TAG is either a
# comma-separated list of lowercase tags or a capitalized project name, and
# everything after TAG is the task description.
function taskwarrior::quicklogger
    # Directories to scan for quick-log files (ql-*)
    set -l notes_dirs "$HOME/Notes" "$HOME/Notes/Quicklogger" "$WORKTIME_DIR"

    for dir in $notes_dirs
        # Skip directories that don't exist on this machine
        if not test -d "$dir"
            continue
        end

        # -L follows symlinks (~/Notes is a symlink to Syncthing vault)
        # -maxdepth 1 keeps the search non-recursive
        for ql_file in (find -L "$dir" -maxdepth 1 -name 'ql-*' -type f)
            while read -l line
                # Skip blank lines
                test -n "$line"; or continue

                # Tokenise by spaces; idx tracks the current parse position
                set -l tokens (string split ' ' -- "$line")
                set -l idx 1

                # Optional first token: a plain integer means due in N days
                set -l due ""
                if string match -qr '^\d+$' -- "$tokens[1]"
                    set due "$tokens[1]"
                    set idx 2
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
                    # Remaining parts (if any) are plain tags, lowercased for consistency
                    test (count $tag_parts) -gt 1; and set tags (string lower -- $tag_parts[2..-1])
                else
                    set tags (string lower -- $tag_parts)
                end

                # Everything from idx onward is the free-text description
                set -l description ""
                if test $idx -le (count $tokens)
                    set description (string join ' ' -- $tokens[$idx..-1])
                end

                # Build flag args for the helper, omitting empty optional fields
                set -l add_args
                test -n "$due"; and set -a add_args --due $due
                test -n "$project"; and set -a add_args --project $project
                for tag in $tags
                    set -a add_args --tag $tag
                end
                _taskwarrior::add_task $add_args $description
            end <$ql_file
            # Restrict permissions before moving so the file is not world-readable in /tmp
            chmod 600 $ql_file
            mv $ql_file /tmp/
        end
    end
end

# Parses a random-quote entry. If it matches "word: description", echoes project then description (one per line); otherwise echoes empty then entry.
function _taskwarrior::random_quote_parse_entry
    set -l entry "$argv[1]"
    if string match -q -r '^[^:]+: .+' -- $entry
        echo (string lower -- (string trim -- (string replace -r '^([^:]+): (.+)$' '$1' -- $entry)))
        echo (string replace -r '^([^:]+): (.+)$' '$2' -- $entry)
    else
        echo ""
        echo $entry
    end
end

# Fills available +random task slots by picking random bullet-point entries from
# random .md files in the notes/random directory. Each slot gets one entry chosen
# by selecting a random file and then a random "* "-prefixed line within it.
function taskwarrior::random_quote
    set -l random_dir "$HOME/Notes/random"

    # Nothing to do if the random notes directory doesn't exist on this machine
    if not test -d "$random_dir"
        return
    end

    # Check how many pending +random task slots are still open
    set -l slots (taskwarrior::random_slots_left)
    if test $slots -le 0
        return
    end

    # Collect .md files, skipping Syncthing conflict copies which are not canonical
    set -l md_files (find "$random_dir" -name '*.md' -not -name '*.sync-conflict*')
    if test (count $md_files) -eq 0
        return
    end

    # Fill each open slot with one randomly selected task
    for i in (seq $slots)
        # Pick a random .md file from the pool
        set -l file $md_files[(builtin random 1 (count $md_files))]

        # Derive a tag from the filename: strip path and extension, lowercase
        # e.g. /home/paul/Notes/random/Focus.md → focus
        set -l file_tag (string lower -- (string replace -r '\.md$' '' (basename $file)))

        # Extract all bullet entries (lines starting with "* ") and strip the marker
        set -l entries (grep '^\* ' $file | string replace -r '^\* ' '')
        if test (count $entries) -eq 0
            continue
        end

        # Pick one entry at random and tag it with both +random and the source file tag
        set -l entry $entries[(builtin random 1 (count $entries))]
        set -l parsed (_taskwarrior::random_quote_parse_entry $entry)
        set -l add_args --tag random --tag $file_tag
        test -n "$parsed[1]"; and set -a add_args --project $parsed[1]
        test (builtin random 1 10) -eq 1; and set -a add_args --tag work
        _taskwarrior::add_task $add_args $parsed[2]
    end
end

function taskwarrior::invoke
    taskwarrior::export
    taskwarrior::import
    taskwarrior::cleanup
    taskwarrior::random_quote
    taskwarrior::unscheduled
    taskwarrior::quicklogger
end

abbr -a t task
abbr -a log 'task add +log'
abbr -a tdue 'tasksamurai status:pending due.before:now'
abbr -a tasks 'tasksamurai -track'
abbr -a track 'taskwarrior::add::track'
abbr -a ti 'taskwarrior::invoke'
abbr -a ts 'taskwarrior::invoke; tasksamurai'

taskwarrior::due_count
