function taskwarrior::fuzzy::_select
    sed -n '/^[0-9]/p' | sort -rn | fzf | cut -d' ' -f1
end

function taskwarrior::fuzzy::find
    set -g TASK_ID (task ready | taskwarrior::fuzzy::_select)
end

function taskwarrior::select
    set -l task_id "$argv[1]"
    if test -n "$task_id"
        set -g TASK_ID "$task_id"
    end
    if test "$TASK_ID" = - -o -z "$TASK_ID"
        taskwarrior::fuzzy::find
    end
end

function taskwarrior::due::count
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

function taskwarrior::add::standup
    if test (count $argv) -gt 0
        task add priority:L +work +standup +sre +nosched $argv
        task add priority:L +work +standup +storage +nosched $argv

        if test -f ~/git/helpers/jira/jira.rb
            echo "Do you want to raise a Jira ticket? (y/n)"
            read -l user_input
            if test "$user_input" = y
                ruby ~/git/helpers/jira/jira.rb --raise "$argv"
            end
        end

    else
        tasksamurai +standup
    end
end

function taskwarrior::add::standup::editor
    set -l tmpfile (mktemp /tmp/standup.XXXXXX.txt)
    $EDITOR $tmpfile
    taskwarrior::add::standup (cat $tmpfile)
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

set -g TASKWARRIOR_FEEDER_PERSONAL_TIMESPAN_D 30
set -g TASKWARRIOR_FEEDER_WORK_TIMESPAN_D 14
set -g TASKWARRIOR_FEEDER_MAX_PENDING_RANDOM_TASKS 42
set -g TASKWARRIOR_FEEDER_GOS_DIR ~/.gosdir

function taskwarrior::feeder::is_personal_device
    test (uname) = Linux
end

function taskwarrior::feeder::random_count
    task status:pending +random -work count
end

function taskwarrior::feeder::random_slots_left
    set -l pending (taskwarrior::feeder::random_count)
    math $TASKWARRIOR_FEEDER_MAX_PENDING_RANDOM_TASKS - $pending
end

function taskwarrior::feeder::normalize_tags
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

function taskwarrior::feeder::task_add
    set -l tags_csv "$argv[1]"
    set -l quote "$argv[2]"
    set -l due "$argv[3]"
    set -l tags (taskwarrior::feeder::normalize_tags "$tags_csv")
    set -l normalized_tags

    if test -z "$quote"
        echo "Not adding task with empty quote"
        return
    end

    if contains -- tr $tags
        set tags (string match -v -- tr $tags)
        set -a tags track
    end
    if contains -- mentoring $tags; or contains -- productivity $tags
        set -a tags work
    end
    for tag in $tags
        if not contains -- "$tag" $normalized_tags
            set -a normalized_tags "$tag"
        end
    end
    set tags $normalized_tags

    if contains -- task $tags
        eval "task $quote"
        return
    end

    set -l project
    for tag in $tags
        if string match -rq '^[A-Z]' -- "$tag"
            set project (string lower -- "$tag")
            set -l remaining_tags
            for entry in $tags
                if test "$entry" != "$tag"
                    set -a remaining_tags "$entry"
                end
            end
            set tags $remaining_tags
            break
        end
    end

    set -l priority
    if contains -- high $tags
        set priority H
    end

    set -l task_args add due:$due
    if test -n "$priority"
        set -a task_args priority:$priority
    end
    if test -n "$project"
        set -a task_args project:$project
    end
    for tag in $tags
        set -a task_args +$tag
    end
    set -a task_args "$quote"
    task $task_args
end

function taskwarrior::feeder::skill_add
    set -l skills_str "$argv[1]"
    set -l skills_file "$WORKTIME_DIR/skills.txt"
    set -l tmp_file "$skills_file.tmp"
    set -l incoming_file "$tmp_file.incoming"
    set -l existing_file "$tmp_file.existing"

    touch "$skills_file"
    printf '%s\n' (string split ',' -- "$skills_str" | string trim) | sed '/^$/d' >"$incoming_file"
    cp "$skills_file" "$existing_file"

    cat "$incoming_file" "$existing_file" | awk '{ k=tolower($0); if (!seen[k]++) print $0 }' >"$tmp_file"
    mv "$tmp_file" "$skills_file"
    rm -f "$incoming_file" "$existing_file"
end

function taskwarrior::feeder::worklog_add
    set -l tag "$argv[1]"
    set -l quote "$argv[2]"
    set -l due "$argv[3]"
    set -l file "$WORKTIME_DIR/wl-"(date +%s)"n.txt"
    set -l due_days (string trim -r -c d -- "$due")
    set -l content "$due_days $tag $quote"

    echo "$file: $content"
    printf '%s\n' "$content" >"$file"
end

function taskwarrior::feeder::gos_queue
    set -l tags_csv "$argv[1]"
    set -l message "$argv[2]"
    set -l tags (taskwarrior::feeder::normalize_tags "$tags_csv")
    set -l platforms
    set -l normalized_tags

    for tag in $tags
        switch "$tag"
            case share
                continue
            case linkedin li mastodon ma noop no
                set -a platforms "$tag"
            case '*'
                set -a normalized_tags "$tag"
        end
    end

    if test (count $platforms) -gt 0
        set -l share_tags share
        set -a share_tags $platforms
        set normalized_tags (string join : -- $share_tags) $normalized_tags
    else if test (count $normalized_tags) -eq 1
        if not string match -rq '^share' -- "$normalized_tags[1]"
            set normalized_tags share $normalized_tags
        end
    end

    set -l tags_str (string join , -- $normalized_tags)
    if test -n "$tags_str"
        set message "$tags_str $message"
    end

    mkdir -p "$TASKWARRIOR_FEEDER_GOS_DIR"
    set -l hash (printf '%s' "$message" | md5sum | awk '{print $1}')
    set -l file "$TASKWARRIOR_FEEDER_GOS_DIR/$hash.txt"
    echo "Writing $file with $message"
    printf '%s\n' "$message" >"$file"
end

function taskwarrior::feeder::notes
    set -l notes_dirs_csv "$argv[1]"
    set -l prefix "$argv[2]"
    set -l router_fn "$argv[3]"
    set -l notes_dirs (string split ',' -- "$notes_dirs_csv")

    for notes_dir in $notes_dirs
        for notes_file in "$notes_dir"/"$prefix"-*
            if not test -f "$notes_file"
                continue
            end

            set -l content (string trim -- (string join \n -- (cat "$notes_file")))
            set -l matches (string match -r '^(?:([0-9]+)[[:space:]]*)?([A-Za-z][A-Za-z0-9:-]*(?:,[A-Za-z][A-Za-z0-9:-]*)*)[[:space:]]*(.*)' -- "$content")
            if test (count $matches) -lt 3
                continue
            end

            set -l due_n
            set -l tags_csv
            set -l body
            if test (count $matches) -eq 4
                set due_n "$matches[2]"
                set tags_csv "$matches[3]"
                set body "$matches[4]"
            else
                set tags_csv "$matches[2]"
                set body "$matches[3]"
            end
            set -l tags (taskwarrior::feeder::normalize_tags "$tags_csv")
            set -a tags "$prefix"
            set tags_csv (string join , -- $tags)

            set -l due
            if test -n "$due_n"
                set due "$due_n"d
            else if contains -- track $tags
                set due eow
            else
                set due (builtin random 0 $TASKWARRIOR_FEEDER_PERSONAL_TIMESPAN_D)d
            end

            $router_fn "$tags_csv" "$body" "$due"
            rm -f "$notes_file"
        end
    end
end

function taskwarrior::feeder::random_quote
    set -l md_file "$argv[1]"
    set -l router_fn "$argv[2]"
    set -l tag (string lower -- (path change-extension '' (path basename "$md_file")))
    set -l timespan

    if taskwarrior::feeder::is_personal_device
        set timespan $TASKWARRIOR_FEEDER_PERSONAL_TIMESPAN_D
    else
        set timespan $TASKWARRIOR_FEEDER_WORK_TIMESPAN_D
    end

    set -l first_line (head -n 1 "$md_file")
    set -l override (string match -r --groups-only '.*\(([0-9]+)\).*' -- "$first_line")
    if test (count $override) -gt 0
        set timespan $override[1]
    end

    set -l quote (string sub -s 3 -- (grep '^\* ' "$md_file" | shuf -n1))
    if test -z "$quote"
        return
    end

    set -l tags "$tag,random"
    if test (builtin random 1 4) -eq 1
        set tags "$tags,work"
    end
    set -l due (builtin random 0 $timespan)d

    $router_fn "$tags" "$quote" "$due"
end

function taskwarrior::feeder::schedule_ids
    set -l filter "$argv[1]"
    set -l due "$argv[2]"
    set -l filter_args (string split ' ' -- "$filter")
    set -l ids (task status:pending $filter_args rc.verbose:nothing export | jq -r '.[] | (.id // 0) | select(. > 0)')

    for id in $ids
        timeout 5s task modify "$id" due:$due
    end
end

function taskwarrior::feeder::schedule
    taskwarrior::feeder::schedule_ids "+track due:" eow
    for id in (task status:pending -unsched -nosched -meeting -track due: rc.verbose:nothing export | jq -r '.[] | (.id // 0) | select(. > 0)')
        timeout 5s task modify "$id" due:(builtin random 0 $TASKWARRIOR_FEEDER_PERSONAL_TIMESPAN_D)d
    end
end

function taskwarrior::feeder::import_gos_json
    if not test -d "$TASKWARRIOR_FEEDER_GOS_DIR"
        return
    end

    for tw_gos in "$WORKTIME_DIR"/tw-gos-*.json
        if not test -f "$tw_gos"
            continue
        end

        jq -c '.[]' "$tw_gos" | while read -l entry
            set -l tags_csv (echo "$entry" | jq -r '.tags | join(",")')
            set -l description (echo "$entry" | jq -r '.description')
            taskwarrior::feeder::gos_queue "$tags_csv" "$description"
        end
        rm -f "$tw_gos"
    end
end

function taskwarrior::feeder::router
    set -l tags_csv "$argv[1]"
    set -l note "$argv[2]"
    set -l due "$argv[3]"
    set -l tags (taskwarrior::feeder::normalize_tags "$tags_csv")

    if contains -- skill $tags; or contains -- skills $tags
        taskwarrior::feeder::skill_add "$note"
    else
        for tag in $tags
            if string match -rq '^share' -- "$tag"
                taskwarrior::feeder::gos_queue "$tags_csv" "$note"
                return
            end
        end
        taskwarrior::feeder::task_add "$tags_csv" "$note" "$due"
    end
end

function taskwarrior::feeder
    set -l notes_dirs "$HOME/Notes,$HOME/Notes/Quicklogger,$WORKTIME_DIR"
    set -l random_dir "$HOME/Notes/random"
    set -l prefixes

    if taskwarrior::feeder::is_personal_device
        set prefixes ql pl
    else
        set prefixes wl
    end

    for prefix in $prefixes
        taskwarrior::feeder::notes "$notes_dirs" "$prefix" taskwarrior::feeder::router
    end

    set -l count (taskwarrior::feeder::random_slots_left)
    if test -d "$random_dir"
        for md_file in (find "$random_dir" -name '*.md' | sort -R)
            if test $count -le 0
                break
            end
            if test (builtin random 0 1) -eq 0
                continue
            end

            taskwarrior::feeder::random_quote "$md_file" taskwarrior::feeder::task_add
            set count (math "$count - 1")
        end
    end

    taskwarrior::feeder::import_gos_json
    taskwarrior::feeder::schedule
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

function taskwarrior::export::gos
    task +share status:pending export >"$WORKTIME_DIR/tw-gos-export-$(date +%s).json"
    yes | task +share status:pending delete
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

function taskwarrior::db::prune
    yes | task +random status:completed delete
    yes | task +agent status:completed delete
end

function taskwarrior::invoke
    taskwarrior::feeder
    tasksamurai
end

abbr -a t task
abbr -a L 'task add +log'
abbr -a tlog 'task add +log'
abbr -a log 'task add +log'
abbr -a tdue 'tasksamurai status:pending due.before:now'
abbr -a thome 'tasksamurai +home'
abbr -a tasks 'tasksamurai -track'
abbr -a tread 'tasksamurai +read'
abbr -a track 'taskwarrior::add::track'
abbr -a tra 'taskwarrior::add::track'
abbr -a trat 'timr track'
abbr -a tfind 'taskwarrior::fuzzy::find'
abbr -a ts 'taskwarrior::invoke'

# Virtual standup abbrs
abbr -a V 'taskwarrior::add::standup'
abbr -a Vstorage 'tasksamurai +standup +storage'
abbr -a Vsre 'tasksamurai +standup +sre'
abbr -a Ved 'taskwarrior::add::standup::editor'

taskwarrior::due::count
