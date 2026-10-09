set -g TASKWARRIOR_MAX_PENDING_RANDOM_TASKS 42
set -gx TASKWARRIOR_DUE_STAMP_FILE ~/.taskwarrior_due.last

function taskwarrior::due_count
    set -l due_count (task status:pending due.before:now count)

    if test $due_count -gt 0
        echo "There are $due_count tasks due!"
    end
end

# Shell-startup wrapper around taskwarrior::due_count. Invoking `task` costs
# ~88ms, which was ~70% of the total fish startup time when it ran in every
# single shell. The stamp file holds the calendar day of the last run, so the
# reminder shows up once in the first terminal of the day and every shell
# opened afterwards starts instantly.
function taskwarrior::due_count::daily
    set -l today (date +%Y-%m-%d)

    if test -f $TASKWARRIOR_DUE_STAMP_FILE
        and test (cat $TASKWARRIOR_DUE_STAMP_FILE) = $today
        return
    end

    # Stamp before counting, so days without any due task also stay quiet
    # instead of re-running `task` in every shell.
    echo $today >$TASKWARRIOR_DUE_STAMP_FILE.tmp
    mv $TASKWARRIOR_DUE_STAMP_FILE.tmp $TASKWARRIOR_DUE_STAMP_FILE

    taskwarrior::due_count
end

function taskwarrior::project_tasks
    set -l project (basename (git rev-parse --show-toplevel))
    task +project:$project status:pending
end

function taskwarrior::project_tasks::tasksamurai
    set -l project (basename (git rev-parse --show-toplevel))
    tasksamurai +project:$project status:pending
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
    return 0
end

# function taskwarrior::is_personal_device
#     test (uname) = Linux
# end

function taskwarrior::random_count
    task status:pending +random -work count
end

function taskwarrior::random_slots_left
    set -l pending (taskwarrior::random_count)
    or return 1
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
    set -l failed 0
    if test -d ~/Notes/Bulgarian
        # Export bulgarian dumi. Keep the task until task export, jq, and the
        # final compacted note all succeed. In particular, a command that
        # emits partial JSON and then fails must not make us delete tasks that
        # were absent from that partial export.
        set -l json (task +bd status:pending export)
        set -l export_status $status
        set -l entries (printf '%s\n' "$json" | jq -r '.[].description')
        set -l parse_status $pipestatus
        set -l uuids (printf '%s\n' "$json" | jq -r '.[].uuid')
        set -l uuid_status $pipestatus
        set -l outfile ~/Notes/Bulgarian/bd-(date +%s).txt
        or set failed 1
        set -l should_delete 0
        if test $export_status -ne 0; or test $parse_status[1] -ne 0; or test $parse_status[2] -ne 0; or test $uuid_status[1] -ne 0; or test $uuid_status[2] -ne 0; or test (count $entries) -ne (count $uuids)
            set failed 1
        end
        if test $export_status -eq 0; and test $parse_status[1] -eq 0; and test $parse_status[2] -eq 0; and test $uuid_status[1] -eq 0; and test $uuid_status[2] -eq 0; and test (count $entries) -gt 0; and test (count $entries) -eq (count $uuids)
            if printf '%s\n' $entries >$outfile
                set should_delete 1
            else
                set failed 1
            end
        else
            touch $outfile
            or set failed 1
        end
        set -l compact_tmp ~/Notes/Bulgarian/compact-(date +%s).tmp
        or set failed 1
        set -l compacted_note ~/Notes/Bulgarian/bd-compacted.txt
        set -l final_tmp $compacted_note.tmp
        set -l source_files
        for source_file in ~/Notes/Bulgarian/bd-*.txt
            if test "$source_file" != "$compacted_note"
                set -a source_files $source_file
            end
        end
        # Keep the previous compacted note as input, but never remove it with
        # the dated source files after installing its replacement.
        set -l compact_inputs $source_files
        if test -f $compacted_note
            set -a compact_inputs $compacted_note
        end
        cat $compact_inputs | sort -u >$compact_tmp
        set -l compact_status $pipestatus
        if test $compact_status[1] -ne 0; or test $compact_status[2] -ne 0
            set failed 1
        end
        if test $compact_status[1] -eq 0; and test $compact_status[2] -eq 0; and sort -u $compact_tmp >$final_tmp; and test -s $final_tmp; and mv $final_tmp $compacted_note
            set -l exported_entries_present 1
            if test $should_delete -eq 1
                for entry in $entries
                    if not grep -Fqx -- "$entry" $compacted_note
                        set exported_entries_present 0
                        set failed 1
                        break
                    end
                end
            end
            if test -f $compacted_note; and test $exported_entries_present -eq 1
                rm $source_files $compact_tmp
                or set failed 1
                if test $should_delete -eq 1
                    for uuid in $uuids
                        yes | task "$uuid" delete
                        or set failed 1
                    end
                end
            else
                set failed 1
            end
        else if test -f $outfile; and not test -s $outfile
            rm -f $outfile $compact_tmp $final_tmp
            or set failed 1
        else
            set failed 1
        end
    end
    return $failed
end

function taskwarrior::export::maybe
    set -l maybefile ~/Notes/random/Maybe.md
    set -l failed 0
    if test -f $maybefile
        touch $maybefile.tmp.1
        or set failed 1
        # Export all maybe project tags. Defer deletion until the assembled
        # note is atomically installed, so a failure writing the final note or
        # a partial task export cannot lose any tasks.
        set -l exported_uuids
        for tag in m may maybe
            set -l json (task +$tag -random status:pending export)
            set -l export_status $status
            set -l entries (printf '%s\n' "$json" | jq -r '.[] | "\(.project): \(.description)"' | sed 's/^/* /')
            set -l parse_status $pipestatus
            set -l uuids (printf '%s\n' "$json" | jq -r '.[].uuid')
            set -l uuid_status $pipestatus
            if test $export_status -ne 0; or test $parse_status[1] -ne 0; or test $parse_status[2] -ne 0; or test $parse_status[3] -ne 0; or test $uuid_status[1] -ne 0; or test $uuid_status[2] -ne 0; or test (count $entries) -ne (count $uuids)
                set failed 1
                continue
            end
            if test (count $entries) -gt 0
                if printf '%s\n' $entries >>$maybefile.tmp.1
                    set -a exported_uuids $uuids
                else
                    set failed 1
                end
            end
        end
        grep -F '* ' $maybefile >>$maybefile.tmp.1
        if test $status -gt 1
            return 1
        end

        if echo "# Maybe (7)" >$maybefile.tmp.2; and echo '' >>$maybefile.tmp.2; and echo 'Thinks I maybe will do something about or maybe not' >>$maybefile.tmp.2; and echo '' >>$maybefile.tmp.2; and sort -u $maybefile.tmp.1 >>$maybefile.tmp.2; and test -s $maybefile.tmp.2; and mv $maybefile.tmp.2 $maybefile
            rm $maybefile.tmp.1
            or set failed 1
            for uuid in $exported_uuids
                yes | task "$uuid" delete
                or set failed 1
            end
        else
            set failed 1
        end
    end
    return $failed
end

# Routes +add tagged tasks into per-project note files under ~/Notes/random/,
# e.g. project:podgore +add "some note" appends "* some note" to
# ~/Notes/random/podgore.md, creating the file with a title header the first
# time that project is seen. Mirrors export::maybe/export::wins but keyed by
# project instead of a single fixed file, so it processes tasks one at a time
# by uuid (like gos_queue) rather than as a batch export.
function taskwarrior::export::add
    set -l notes_dir ~/Notes/random
    if not test -d $notes_dir
        return 0
    end

    set -l uuids (task +add status:pending _uuids)
    or return 1
    set -l failed 0
    for uuid in $uuids
        test -n "$uuid"; or continue
        set -l json (task "$uuid" export)
        if test $status -ne 0
            set failed 1
            continue
        end
        set -l project (echo "$json" | jq -r '.[0].project // ""')
        if test $pipestatus[2] -ne 0
            set failed 1
            continue
        end
        set -l description (echo "$json" | jq -r '.[0].description')
        if test $pipestatus[2] -ne 0
            set failed 1
            continue
        end

        # A task without a project has no file to route to; leave it pending
        # rather than silently discarding the note
        if test -z "$project"
            continue
        end

        set -l outfile "$notes_dir/$project.md"
        set -l write_failed 0
        if not test -f $outfile
            # Match the "# Title (30)" header convention used by the other
            # files in $notes_dir (the "(30)" is their random-quote review interval)
            set -l title (string upper -- (string sub -l 1 -- $project))(string sub -s 2 -- $project)
            echo "# $title (30)" >$outfile
            or set write_failed 1
            echo '' >>$outfile
            or set write_failed 1
        end
        # The delete may only run once the note line was appended; a failed
        # write must not lose the note.
        if test $write_failed -eq 0; and echo "* $description" >>$outfile
            yes | task "$uuid" delete &>/dev/null
            or set failed 1
        else
            echo "Export failed: $outfile; keeping the note '$description'" >&2
            set failed 1
        end
    end
    return $failed
end

function taskwarrior::export::wins
    set -l winsfile ~/Notes/random/Wins.md
    set -l failed 0
    if test -f $winsfile
        touch $winsfile.tmp.1
        or set failed 1
        # Export all wins tags. Defer deletion until the assembled note is
        # atomically installed and require each export and parse to succeed.
        set -l exported_uuids
        for tag in win wins
            set -l json (task +$tag -random status:pending export)
            set -l export_status $status
            set -l entries (printf '%s\n' "$json" | jq -r '.[].description' | sed 's/^/* /')
            set -l parse_status $pipestatus
            set -l uuids (printf '%s\n' "$json" | jq -r '.[].uuid')
            set -l uuid_status $pipestatus
            if test $export_status -ne 0; or test $parse_status[1] -ne 0; or test $parse_status[2] -ne 0; or test $parse_status[3] -ne 0; or test $uuid_status[1] -ne 0; or test $uuid_status[2] -ne 0; or test (count $entries) -ne (count $uuids)
                set failed 1
                continue
            end
            if test (count $entries) -gt 0
                if printf '%s\n' $entries >>$winsfile.tmp.1
                    set -a exported_uuids $uuids
                else
                    set failed 1
                end
            end
        end
        grep -F '* ' $winsfile >>$winsfile.tmp.1
        if test $status -gt 1
            return 1
        end

        if echo "# wins (7)" >$winsfile.tmp.2; and echo '' >>$winsfile.tmp.2; and echo 'Wins I had' >>$winsfile.tmp.2; and echo '' >>$winsfile.tmp.2; and sort -u $winsfile.tmp.1 >>$winsfile.tmp.2; and test -s $winsfile.tmp.2; and mv $winsfile.tmp.2 $winsfile
            rm $winsfile.tmp.1
            or set failed 1
            for uuid in $exported_uuids
                yes | task "$uuid" delete &>/dev/null
                or set failed 1
            end
        else
            set failed 1
        end
    end
    return $failed
end

# Exports all tasks tagged +$tag for both pending and completed status into
# per-status .json files in $WORKTIME_DIR, then deletes the exported tasks. The
# tag name doubles as the file label (tw-<tag>-export-<ts>-<host>-<status>.json)
# so the importer can match the files again by tag name or, for host-routed tags
# like "earth", "rocky", and "zen", by hostname. The <host> segment keeps
# same-second exports from different hosts (this dir is git-synced) from
# clobbering each other's files. See _taskwarrior::import_label for the
# matching side.
function _taskwarrior::export_tag
    set -l tag $argv[1]
    set -l ts $argv[2]
    set -l host (hostname)
    set -l failed 0

    for task_status in pending completed
        set -l count (task +$tag status:$task_status count)
        if test $status -ne 0
            set failed 1
            continue
        end

        if test $count -eq 0
            continue
        end

        set -l outfile "$WORKTIME_DIR/tw-$tag-export-$ts-$host-$task_status.json"

        echo "Exporting $count $task_status tasks tagged +$tag"
        # Delete only after the export file was written successfully; a failed
        # write (e.g. missing $WORKTIME_DIR) must not lose the tasks. A failed
        # redirection skips `task export` entirely, so this catches a bad path
        # as well as a failing export. Remove a partial file so it is neither
        # git-synced nor imported with an error by the receiving host.
        if task +$tag status:$task_status export >"$outfile"; and test -s "$outfile"
            yes | task +$tag status:$task_status delete &>/dev/null
            or set failed 1
        else
            rm -f "$outfile"
            or set failed 1
            echo "Export failed: $outfile; keeping $count $task_status tasks tagged +$tag" >&2
            set failed 1
        end
    end
    return $failed
end

# Imports every export file in $WORKTIME_DIR whose embedded label (the <label>
# in tw-<label>-export-*.json) matches $label, and removes each file only after
# it was imported successfully — a failed import must not consume the export.
# The label is either a tag name or a hostname. See _taskwarrior::export_tag
# for the producing side.
function _taskwarrior::import_label
    set -l label $argv[1]

    set -l imports (find $WORKTIME_DIR -name "tw-$label-export-*.json")
    or return 1
    set -l failed 0
    for import in $imports
        if task import $import
            rm $import
            or set failed 1
        else
            set failed 1
        end
    end
    return $failed
end

function taskwarrior::export
    _taskwarrior::set_import_export_tags; or return 1
    set -l ts (date +%s)
    or return 1
    set -l failed 0

    # Export this host's outgoing work/personal tag plus host-routed +earth,
    # +rocky, and +zen tasks — except this host's own name. Local +$hostname
    # tasks already live here; exporting them would delete them and only have
    # the same host re-import the files. Other hosts still export those tags
    # so this machine can import them via hostname. A task tagged with several
    # routing tags (e.g. +zen +work) is exported once under the first matching
    # label in the loop order and relays from there.
    set -l host (hostname)
    for tag in $TASK_EXPORT_TAG earth rocky zen
        if test "$tag" = "$host"
            continue
        end
        _taskwarrior::export_tag $tag $ts
        or set failed 1
    end

    taskwarrior::export::bd
    or set failed 1
    taskwarrior::export::maybe
    or set failed 1
    taskwarrior::export::wins
    or set failed 1
    taskwarrior::export::add
    or set failed 1
    return $failed
end

function taskwarrior::import
    _taskwarrior::set_import_export_tags; or return 1
    set -l failed 0

    # Import files labelled with this host's incoming work/personal tag, plus
    # files labelled with this host's name. The +earth / +rocky / +zen exports
    # are labelled with those hostnames, so only the matching host imports
    # them; other hosts leave the files in place for the destination to pick
    # up.
    for label in $TASK_IMPORT_TAG (hostname)
        _taskwarrior::import_label $label
        or set failed 1
    end
    return $failed
end

# SQL epoch matching Taskwarrior's today-DAYSdays filter: local midnight minus
# DAYS*86400 seconds, so the SQLite pre-selection and the task filter agree.
function _taskwarrior::cutoff_sql
    echo "(CAST(strftime('%s', 'now', 'localtime', 'start of day', 'utc') AS INTEGER) - $argv[1] * 86400)"
end

# SQL condition skipping recurrence templates (mask set) that still have a
# non-deleted child: purging such a template aborts the whole task command.
# Templates whose children are all deleted stay eligible; purge takes their
# deleted children along.
function _taskwarrior::no_live_children_sql
    echo "AND NOT (json_extract(data, '\$.mask') IS NOT NULL AND uuid IN (
        SELECT json_extract(c.data, '\$.parent') FROM tasks c
        WHERE json_extract(c.data, '\$.parent') IS NOT NULL
          AND json_extract(c.data, '\$.status') != 'deleted'))"
end

# Fast UUID batch from taskchampion.sqlite3 (avoids TW3 loading the whole set).
# Usage: _taskwarrior::old_uuids STATUS DATE_FIELD LIMIT DAYS [TAG]
# STATUS: completed|deleted  DATE_FIELD: end|modified
function _taskwarrior::old_uuids
    set -l tw_status $argv[1]
    set -l field $argv[2]
    set -l batch $argv[3]
    set -l days $argv[4]
    set -l tag $argv[5]
    test -n "$days"; or set days 90

    set -l data_dir $HOME/.task
    test -n "$TASKDATA"; and set data_dir $TASKDATA
    set -l db $data_dir/taskchampion.sqlite3
    test -f $db; or return 1

    set -l tag_sql ''
    if test -n "$tag"
        set tag_sql "AND (',' || COALESCE(json_extract(data, '\$.tags'), '') || ',' LIKE '%,$tag,%')"
    end

    sqlite3 $db "
        SELECT uuid FROM tasks
        WHERE json_extract(data, '\$.status') = '$tw_status'
          AND CAST(json_extract(data, '\$.$field') AS INTEGER)
              < $(_taskwarrior::cutoff_sql $days)
          $tag_sql
          $(_taskwarrior::no_live_children_sql)
        LIMIT $batch;
    "
end

# Count matching old tasks. Usage: _taskwarrior::old_count STATUS DATE_FIELD DAYS [TAG]
function _taskwarrior::old_count
    set -l tw_status $argv[1]
    set -l field $argv[2]
    set -l days $argv[3]
    set -l tag $argv[4]
    test -n "$days"; or set days 90

    set -l data_dir $HOME/.task
    test -n "$TASKDATA"; and set data_dir $TASKDATA
    set -l db $data_dir/taskchampion.sqlite3
    test -f $db; or return 1

    set -l tag_sql ''
    if test -n "$tag"
        set tag_sql "AND (',' || COALESCE(json_extract(data, '\$.tags'), '') || ',' LIKE '%,$tag,%')"
    end

    sqlite3 $db "
        SELECT COUNT(*) FROM tasks
        WHERE json_extract(data, '\$.status') = '$tw_status'
          AND CAST(json_extract(data, '\$.$field') AS INTEGER)
              < $(_taskwarrior::cutoff_sql $days)
          $tag_sql
          $(_taskwarrior::no_live_children_sql);
    "
end

# Archive UUID payloads via sqlite (task export loads the whole DB and can hang).
# Usage: _taskwarrior::archive_uuids OUTFILE UUID…
function _taskwarrior::archive_uuids
    set -l outfile $argv[1]
    set -l uuids $argv[2..-1]
    test (count $uuids) -gt 0; or return 0

    set -l data_dir $HOME/.task
    test -n "$TASKDATA"; and set data_dir $TASKDATA
    set -l db $data_dir/taskchampion.sqlite3

    set -l tmp (mktemp "$outfile.XXXXXX"); or return 1
    set -l expected (count $uuids)
    set -l in_list (string join "','" $uuids)
    if not sqlite3 $db "
        SELECT json_group_array(json(data)) FROM tasks
        WHERE uuid IN ('$in_list')
        HAVING COUNT(*) = $expected;
    " >$tmp
        rm -f $tmp
        return 1
    end
    if not test -s $tmp
        rm -f $tmp
        return 1
    end
    # Validate the bytes written, including short writes and malformed JSON.
    set -l tmp_sql (string replace -a "'" "''" -- $tmp)
    set -l archived_count (sqlite3 :memory: "SELECT json_array_length(readfile('$tmp_sql'));")
    if test $status -ne 0; or test "$archived_count" != "$expected"
        rm -f $tmp
        return 1
    end
    # Hard-link creation fails if another cleanup already published this name.
    if not ln $tmp $outfile
        rm -f $tmp
        return 1
    end
    rm -f $tmp; or return 1
end

# Run a bulk task command without any prompt. rc.confirmation=off alone is not
# enough: once a command touches rc.bulk (default 3) or more tasks, Taskwarrior
# asks per task (yes/no/all/quit) regardless. rc.bulk=0 means "no bulk limit",
# so cleanup stays unattended however many tasks are due.
# recurrence.confirmation (default prompt) has its own prompt; =no keeps delete
# from also deleting the pending siblings of an old recurring instance. Purge
# overrides it with =yes, as =no aborts purging a template with deleted children.
function _taskwarrior::unattended
    task rc.confirmation=off rc.bulk=0 rc.gc=0 rc.verbose:nothing \
        rc.recurrence.confirmation=no $argv
end

# Called from taskwarrior::invoke (hence supersync): delete tasks completed and
# purge tasks deleted at least 90 days ago. Both use the task's end timestamp
# (set on completion and on deletion); modified is bumped by later syncs and
# imports, so it does not say how long a task has been deleted. Completed
# +agent tasks are archived before deletion.
# All destructive calls go through _taskwarrior::unattended so supersync never
# blocks on a confirmation prompt.
function taskwarrior::cleanup
    set -l days 90
    set -l data_dir $HOME/.task
    test -n "$TASKDATA"; and set data_dir $TASKDATA
    set -l agent_history_dir $data_dir/AgentsHistory

    set -l agent (_taskwarrior::old_uuids completed end 100000 $days agent)
    if test $status -ne 0
        echo "taskwarrior::cleanup: unable to find old +agent tasks; skipping cleanup" >&2
        return 1
    end
    # The UUID query has a limit; never delete tasks it did not select.
    set -l agent_count (_taskwarrior::old_count completed end $days agent)
    if test $status -ne 0; or test "$agent_count" != (count $agent)
        echo "taskwarrior::cleanup: old +agent task count differs from selected UUIDs; skipping cleanup" >&2
        return 1
    end
    if test (count $agent) -gt 0
        if not test -d $agent_history_dir
            mkdir -p $agent_history_dir; or return 1
        end
        set -l agent_export "$agent_history_dir/tw-agent-export-"(date +%Y%m%d-%H%M%S)"-$fish_pid-"(builtin random 1 999999)".json"
        echo "taskwarrior::cleanup: archiving "(count $agent)" +agent → $agent_export"
        if not _taskwarrior::archive_uuids $agent_export $agent
            echo "taskwarrior::cleanup: archive failed; skipping cleanup" >&2
            return 1
        end
    end

    set -l n (_taskwarrior::old_count completed end $days)
    if test $status -ne 0
        echo "taskwarrior::cleanup: unable to count old completed tasks; skipping cleanup" >&2
        return 1
    end
    if test $n -eq 0
        echo "taskwarrior::cleanup: no completed ≥"$days"d"
    else
        # New +agent tasks can become eligible after the archive query. The
        # broad filter therefore excludes them; archived UUIDs are explicit.
        if test $n -gt $agent_count
            echo "taskwarrior::cleanup: deleting old completed -agent tasks"
            _taskwarrior::unattended \
                status:completed end.before:today-"$days"days -agent delete
            or return 1
        end
        set -l offset 1
        while test $offset -le $agent_count
            set -l last (math $offset + 199)
            if test $last -gt $agent_count
                set last $agent_count
            end
            _taskwarrior::unattended \
                $agent[$offset..$last] status:completed \
                end.before:today-"$days"days +agent delete
            or return 1
            set offset (math $last + 1)
        end
    end

    set -l n (_taskwarrior::old_count deleted end $days)
    if test $status -ne 0
        echo "taskwarrior::cleanup: unable to count old deleted tasks; skipping purge" >&2
        return 1
    end
    if test $n -eq 0
        echo "taskwarrior::cleanup: no deleted ≥"$days"d"
        return 0
    end
    # TW 3.4 purge reloads and dependency-scans every task for each purged
    # task (CmdPurge::handleDeps -> TDB2::all_tasks), ~1.3s each here. Purge
    # in small UUID batches so progress is visible, Ctrl-C keeps finished
    # batches, and later batches scan a smaller task set.
    set -l uuids (_taskwarrior::old_uuids deleted end $n $days)
    if test $status -ne 0
        echo "taskwarrior::cleanup: unable to find old deleted tasks; skipping purge" >&2
        return 1
    end
    set -l total (count $uuids)
    echo "taskwarrior::cleanup: purging $total deleted ≥"$days"d"
    set -l start (date +%s)
    set -l last_report $start
    set -l offset 1
    while test $offset -le $total
        set -l last (math $offset + 4)
        if test $last -gt $total
            set last $total
        end
        _taskwarrior::unattended rc.recurrence.confirmation=yes \
            $uuids[$offset..$last] status:deleted \
            end.before:today-"$days"days purge
        or return 1
        set offset (math $last + 1)
        set -l now (date +%s)
        if test (math $now - $last_report) -ge 10; or test $last -eq $total
            set -l elapsed (math $now - $start)
            set -l eta (math --scale=0 "$elapsed * ($total - $last) / $last")
            echo "taskwarrior::cleanup: purged $last/$total deleted ("$elapsed"s elapsed, ~"$eta"s left)"
            set last_report $now
        end
    end
end

function taskwarrior::unscheduled
    # _ids can emit a trailing empty line; skip empty values to avoid a no-filter modify
    set -l failed 0

    # +auto / +agent tasks without due/scheduled get a fixed due in 6 days (eligible for
    # next-auto-task's 7-day window). Exclude them from the random assignment below.
    set -l auto_ids (task '( +auto or +agent )' status:pending due: scheduled: _ids)
    or return 1
    for id in $auto_ids
        test -n "$id"; or continue
        timeout 5s task modify "$id" due:6d &>/dev/null
        or set failed 1
    end

    # Non-auto/non-agent: random due in 0..42 days
    set -l ids (task status:pending -auto -agent -unsched -nosched -meeting -track -tr due: _ids)
    or return 1
    for id in $ids
        test -n "$id"; or continue
        # echo "timeout 5s task modify $id due:(builtin random 0 30)d"
        timeout 5s task modify "$id" due:(builtin random 0 42)d &>/dev/null
        or set failed 1
    end
    return $failed
end

# Adds a single taskwarrior task. Can be reused anywhere task creation is needed.
# Description is the required positional argument.
# Optional flags:
#   --due N        due in N days (passed as due:Nd to task)
#   --project NAME assign a project
#   --tag TAG      add a tag; repeat for multiple tags
function _taskwarrior::add_task
    argparse 'due=' 'project=' 'tag=+' 'annotate=' -- $argv
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
    # description is escaped so the output is unambiguous even with quotes or special chars.
    # The `--` keeps description text that looks like taskwarrior syntax
    # (+tag, -word) from being parsed as modifiers (verified with TW 3.4.2).
    echo "task add $cmd_args -- "(string escape -- $description)
    set -l created (task add $cmd_args -- $description)
    set -l add_status $status
    echo $created

    # Optional annotation (e.g. source notes path for +random quotes)
    if test -n "$_flag_annotate"
        set -l id (string match -r --groups-only 'Created task (\d+)' -- $created)
        if test -z "$id"
            return 1
        end
        echo "task $id annotate "(string escape -- $_flag_annotate)
        task $id annotate $_flag_annotate
        or return 1
    end

    # Propagate `task add`'s exit status so callers (the quicklog import)
    # can keep failed notes for retry instead of consuming them
    return $add_status
end

# Parses a random-quote entry. If it matches "word: description", echoes project then description (one per line); otherwise echoes empty then entry.
function _taskwarrior::random_quote_parse_entry
    set -l entry "$argv[1]"
    if string match -q -r '^\S+: .+' -- $entry
        echo (string lower -- (string trim -- (string replace -r '^(\S+): (.+)$' '$1' -- $entry)))
        echo (string replace -r '^(\S+): (.+)$' '$2' -- $entry)
    else
        echo ""
        echo $entry
    end
end

function _taskwarrior::fill_random_slot
    set -l file $argv[1]

    # Derive a tag from the filename: strip path and extension, lowercase
    # e.g. /home/paul/Notes/random/Focus.md → focus
    set -l file_tag (string lower -- (string replace -r '\.md$' '' (basename $file)))

    # Extract all bullet entries (lines starting with "* ") and strip the marker
    set -l entries (grep '^\* ' $file | string replace -r '^\* ' '')
    set -l entry_statuses $pipestatus
    if test $entry_statuses[1] -gt 1; or test $entry_statuses[1] -eq 0 -a $entry_statuses[2] -ne 0
        return 1
    end
    if test (count $entries) -eq 0
        return 0
    end

    # Descriptions of pending +random tasks, used to avoid creating duplicates
    set -l existing (task status:pending +random export | jq -r '.[].description')
    set -l export_statuses $pipestatus
    if test $export_statuses[1] -ne 0; or test $export_statuses[2] -ne 0
        return 1
    end

    # Pick a random entry, retrying if its description already exists as a
    # pending +random task. Try at most 3 times; if all attempts collide we give up on this slot rather than looping forever (there may be nothing else to pick).
    set -l parsed
    for attempt in (seq 3)
        set -l entry $entries[(builtin random 1 (count $entries))]
        set -l candidate (_taskwarrior::random_quote_parse_entry $entry)
        if not contains -- "$candidate[2]" $existing
            set parsed $candidate
            break
        end
    end

    # All attempts hit an already-pending task; skip adding for this slot
    if test (count $parsed) -eq 0
        return 0
    end

    # Tag the chosen entry with both +random and the source file tag;
    # annotate with @path so the source notes file is recoverable later
    set -l note_path (string replace -r "^$HOME" '~' -- $file)
    set -l add_args --tag random --tag $file_tag --annotate "@$note_path"
    test -n "$parsed[1]"; and set -a add_args --project $parsed[1]
    test (builtin random 1 10) -eq 1; and set -a add_args --tag work
    _taskwarrior::add_task $add_args $parsed[2]
end

# Fills available +random task slots by picking random bullet-point entries from
# random .md files in the notes/random directory. Each slot gets one entry chosen
# by selecting a random file and then a random "* "-prefixed line within it.
function taskwarrior::random_quote
    set -l random_dir "$HOME/Notes/random"

    # Nothing to do if the random notes directory doesn't exist on this machine
    if not test -d "$random_dir"
        return 0
    end

    # Ensure there is always at least one +maybe task pending, even when the
    # ordinary +random slots are full.
    set -l failed 0
    set -l maybe_count (task status:pending +maybe count)
    if test $status -ne 0; or not string match -qr '^[0-9]+$' -- "$maybe_count"
        set failed 1
    else if test $maybe_count -eq 0
        _taskwarrior::fill_random_slot "$random_dir/Maybe.md"
        or set failed 1
    end

    # Check how many pending +random task slots are still open
    set -l slots (taskwarrior::random_slots_left)
    if test $status -ne 0
        return 1
    end
    if test $slots -le 0
        return $failed
    end

    # Collect .md files, skipping Syncthing conflict copies which are not canonical
    set -l md_files (find "$random_dir" -name '*.md' -not -name '*.sync-conflict*')
    if test $status -ne 0
        return 1
    end
    if test (count $md_files) -eq 0
        return $failed
    end

    # Fill each open slot with one randomly selected task
    for i in (seq $slots)
        set -l file $md_files[(builtin random 1 (count $md_files))]
        _taskwarrior::fill_random_slot $file
        or set failed 1
    end
    return $failed
end

# Known gos platform aliases (must match gos internal/platforms aliases)
set -g TASKWARRIOR_GOS_PLATFORMS li linkedin ma mastodon no noop sno snonux sn x xcom tw twitter

# Exports pending +share tasks to gos queue files in $GOS_DIR.
# Platform tags (e.g. +li, +mastodon) become share:PLATFORM in the gos filename.
# The +soon tag appends ,soon. Tasks are deleted from taskwarrior after export.
function taskwarrior::gos_queue
    set -l gos_dir "$GOS_DIR"
    if not test -d "$gos_dir"
        return 0
    end

    set -l uuids (task +share status:pending _uuids)
    or return 1
    set -l failed 0
    for uuid in $uuids
        test -n "$uuid"; or continue
        set -l json (task "$uuid" export)
        if test $status -ne 0
            set failed 1
            continue
        end
        set -l description (echo "$json" | jq -r '.[0].description')
        if test $pipestatus[2] -ne 0
            set failed 1
            continue
        end
        set -l tags (echo "$json" | jq -r '.[0].tags[]')
        if test $pipestatus[2] -ne 0
            set failed 1
            continue
        end

        # Collect platform tags, modifier tags, and remaining hashtags
        set -l platforms
        set -l modifiers
        set -l hashtags
        for tag in $tags
            if test "$tag" = share
                continue
            else if contains -- "$tag" $TASKWARRIOR_GOS_PLATFORMS
                set -a platforms "$tag"
            else if test "$tag" = soon -o "$tag" = prio -o "$tag" = now -o "$tag" = ask
                set -a modifiers "$tag"
            else if test "$tag" != personal
                set -a hashtags "#$tag"
            end
        end

        # Build the gos inline tag prefix: share:platform1:platform2,modifier1,modifier2
        set -l share_tag share
        for p in $platforms
            set share_tag "$share_tag:$p"
        end
        if test (count $modifiers) -gt 0
            set share_tag "$share_tag,"(string join , -- $modifiers)
        end

        set -l message "$share_tag $description"
        if test (count $hashtags) -gt 0
            set message "$message"\n\n(string join ' ' -- $hashtags)
        end
        set -l hash (printf '%s' "$message" | md5sum | awk '{print $1}')
        set -l hash_statuses $pipestatus
        if test $hash_statuses[1] -ne 0; or test $hash_statuses[2] -ne 0; or test $hash_statuses[3] -ne 0; or test -z "$hash"
            set failed 1
            continue
        end
        set -l file "$gos_dir/$hash.txt"
        echo "Gos queue: $file"
        # The delete may only run once the queue file was written; a failed
        # write must not lose the share.
        if printf '%s\n' "$message" >"$file"; and test -s "$file"; and printf '%s\n' "$message" | cmp -s - "$file"
            yes | task "$uuid" delete &>/dev/null
            or set failed 1
        else
            echo "Gos queue: writing $file failed; keeping the share '$description'" >&2
            set failed 1
        end
    end
    return $failed
end

function taskwarrior::invoke
    set -l failed 0
    taskwarrior::export
    or set failed 1
    taskwarrior::import
    or set failed 1
    taskwarrior::cleanup
    or set failed 1
    taskwarrior::random_quote
    or set failed 1
    taskwarrior::unscheduled
    or set failed 1
    taskwarrior::quicklog_import
    or set failed 1
    taskwarrior::quicklogger
    or set failed 1
    taskwarrior::gos_queue
    or set failed 1
    # Rename tr tag to track
    set -l count (task +tr -track count)
    if test $status -ne 0
        set failed 1
    else if test $count -gt 0
        yes | task +tr -track modify +track -tr
        or set failed 1
    end
    # Add track tag to tr project
    set count (task -track proj:tr count)
    if test $status -ne 0
        set failed 1
    else if test $count -gt 0
        yes | task -track proj:tr modify +track
        or set failed 1
    end
    # All tasks with auto tag also have agent tag
    set count (task +auto -agent count)
    if test $status -ne 0
        set failed 1
    else if test $count -gt 0
        yes | task +auto -agent modify +agent
        or set failed 1
    end
    return $failed
end

# Interactive conveniences only. Headless callers (the quicklog-drain import
# wrapper sets QUICKLOG_HEADLESS=1) source this file purely for its functions
# and must not define abbreviations or run the once-a-day due-count check.
if not set -q QUICKLOG_HEADLESS
    abbr -a ta task
    abbr -a log 'task add +log'
    abbr -a track 'taskwarrior::add::track'
    abbr -a ti 'taskwarrior::invoke; tasksamurai due.before:today+7d'
    abbr -a ts tasksamurai
    abbr tpt taskwarrior::project_tasks
    abbr tsp taskwarrior::project_tasks::tasksamurai
    abbr st 'supersync; tasksamurai due.before:today+7d'
    abbr agenttasks tasksamurai +agent
    abbr agentasks tasksamurai +agent

    taskwarrior::due_count::daily
end
