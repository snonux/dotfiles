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

function taskwarrior::unscheduled
    echo "Scheduling unscheduled tasks (not yet implemented)"
    # taskwarrior::ids "+track due:" eow
    # for id in (task status:pending -unsched -nosched -meeting -track due: rc.verbose:nothing export | jq -r '.[] | (.id // 0) | select(. > 0)')
    #     timeout 5s task modify "$id" due:(builtin random 0 $TASKWARRIOR_PERSONAL_TIMESPAN_D)d
    # end
end

function taskwarrior::quicklogger
    set -l notes_dirs "$HOME/Notes,$HOME/Notes/Quicklogger,$WORKTIME_DIR"
    echo taskwarrior::quicklogger not yet implemented
end

function taskwarrior::random_quote
    set -l random_dir "$HOME/Notes/random"
    echo taskwarrior::random_quote not yet implemented

    # set -l count (taskwarrior::random_slots_left)
    # if test -d "$random_dir"
    #     for md_file in (find "$random_dir" -name '*.md' | sort -R)
    #         if test $count -le 0
    #             break
    #         end
    #         if test (builtin random 0 1) -eq 0
    #             continue
    #         end

    #         taskwarrior::random_quote "$md_file" taskwarrior::task_add
    #         set count (math "$count - 1")
    #     end
    # end
end

function taskwarrior::export::bd
    if test -d ~/Notes/Bulgarian
        # Export bulgarian dumi
        set -l outfile ~/Notes/Bulgarian/bd-(date +%s).txt
        task +bd status:pending export | jq -r '.[].description' >$outfile
        yes | task +bd status:pending delete
        cat ~/Notes/Bulgarian/bd-*.txt | sort -u >~/Notes/Bulgarian/compact-(date +%s).tmp && rm ~/Notes/Bulgarian/bd-*.txt
        sort -u ~/Notes/Bulgarian/compact-*.tmp >~/Notes/Bulgarian/bd-compacted.txt && rm ~/Notes/Bulgarian/compact-*.tmp
    end
end

function taskwarrior::export::pet
    set -l petfile ~/Notes/random/Pet.md
    if test -f $petfile
        # Export all pet project tags
        task +pet -random status:pending export | jq -r '.[].description' | sed 's/^/* /' >>$petfile.tmp.1
        grep -F '* ' $petfile >>$petfile.tmp.1
        yes | task +pet -random status:pending delete

        set -l count (sort -u $petfile.tmp.1 | wc -l | tr -d ' ')
        echo "# Pet ($count)" >$petfile.tmp.2
        echo '' >>$petfile.tmp.2
        sort -u $petfile.tmp.1 >>$petfile.tmp.2 && mv $petfile.tmp.2 $petfile && rm $petfile.tmp.1
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
    taskwarrior::export::pet
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
    yes | task +random status:completed delete
    yes | task +agent status:completed delete
end

function taskwarrior::invoke
    taskwarrior::export
    taskwarrior::import
    taskwarrior::cleanup
    taskwarrior::quicklogger
    taskwarrior::random_quote
    taskwarrior::unscheduled
end

abbr -a t task
abbr -a log 'task add +log'
abbr -a tdue 'tasksamurai status:pending due.before:now'
abbr -a tasks 'tasksamurai -track'
abbr -a track 'taskwarrior::add::track'
abbr -a ti 'taskwarrior::invoke'

taskwarrior::due_count
