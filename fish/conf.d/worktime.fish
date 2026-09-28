set -gx WORKTIME_DIR ~/git/worktime

if test (uname) = Darwin -a ! -f ~/.wtloggedin
    echo "Warn: Not logged in, run wtlogin"
end

function worktime::add
    set -l seconds $argv[1]
    set -l what $argv[2]
    set -l descr $argv[3]

    if test -z "$what"
        set what work
    end

    if test -z "$descr"
        timesamurai work add "$seconds"s $what
    else
        timesamurai work add "$seconds"s $what --descr "$descr"
    end

    worktime::report
end

function worktime::login
    set -l what $argv[1]
    if test -z "$what"
        set what work
    end
    touch ~/.wtloggedin
    timesamurai work start $what
    worktime::wisdom_reminder
end

function worktime::logout
    set -l what $argv[1]

    if test -z "$what"
        set what work
    end

    if test -f ~/.wtloggedin
        rm ~/.wtloggedin
    end

    timesamurai work stop $what
    worktime::report
end

function worktime::edit
    timesamurai work edit $argv
end

function worktime::report
    if test -f ~/.wtloggedin
        if test -f ~/.wtmaster
            timesamurai work report $argv | tee $WORKTIME_DIR/report.txt
        else
            timesamurai work report $argv
        end
        worktime::wisdom_reminder
    end
end

function worktime::status
    worktime::report
    timesamurai work status
end

function worktime::sync
    cd $WORKTIME_DIR
    if test -f ~/.tasksync_enable
        tasksync
    end
    # `git commit -a` only stages tracked files, so the JSONL store's per-host
    # files would never be committed on the host that first creates them.
    find . -name '*.jsonl' -exec git add {} \;
    git commit -a -m sync
    git pull
    git push
    cd -
end

function worktime::supersync_sync
    if not test -d $WORKTIME_DIR
        echo "Warning: Directory $WORKTIME_DIR does not exist"
        return 1
    end
    cd $WORKTIME_DIR
    or return 1
    set -l failed 0

    if test (count $argv) -gt 0 -a $argv[1] = sync_quotes
        if test -d ~/Notes/HabitsAndQuotes
            set -l quote_failed 0
            set -l quote_tmp_dir (mktemp -d .worktime-quotes.XXXXXX)
            if test $status -ne 0
                set quote_failed 1
            else
                echo "" >"$quote_tmp_dir/wisdom-source"
                or set quote_failed 1
                for notes in ~/Notes/random/{Productivity,Mentoring}.md
                    grep '^\* ' $notes >>"$quote_tmp_dir/wisdom-source"
                    if test $status -gt 1
                        set quote_failed 1
                    end
                end
                sort -u "$quote_tmp_dir/wisdom-source" >"$quote_tmp_dir/wisdom"
                or set quote_failed 1
                grep '^\* ' ~/Notes/random/Exercise.md >"$quote_tmp_dir/exercises"
                if test $status -gt 1
                    set quote_failed 1
                end
                if test $quote_failed -eq 0
                    mv "$quote_tmp_dir/wisdom" work-wisdoms.md
                    or set quote_failed 1
                    if test $quote_failed -eq 0
                        mv "$quote_tmp_dir/exercises" exercises.md
                        or set quote_failed 1
                    end
                end
                rm -f "$quote_tmp_dir/wisdom-source" "$quote_tmp_dir/wisdom" "$quote_tmp_dir/exercises"
                or set quote_failed 1
                rmdir "$quote_tmp_dir"
                or set quote_failed 1
            end
            if test $quote_failed -ne 0
                set failed 1
            else
                git add work-wisdoms.md exercises.md
                or set failed 1
            end
        end
    end

    find . -name '*.txt' -exec git add {} +
    or set failed 1
    find . -name '*.json' -exec git add {} +
    or set failed 1
    find . -name '*.csv' -exec git add {} +
    or set failed 1
    find . -name '*.jsonl' -exec git add {} +
    or set failed 1
    if test $failed -eq 0
        git diff --quiet HEAD
        set -l diff_status $status
        if test $diff_status -eq 1
            git commit -a -m sync
            or set failed 1
        else if test $diff_status -gt 1
            set failed 1
        end

        if test $failed -eq 0
            if git pull origin master
                git push origin master
                or set failed 1
            else
                set failed 1
            end
        end
    end

    cd -
    or set failed 1
    return $failed
end

# uprecords collect/import helpers live in the (private) worktime repo so that
# host-specific details stay out of the public dotfiles repo. The functions
# guard internally (collect on Darwin, import on earth).
if test -f $WORKTIME_DIR/scripts/uprecords-sync.fish
    source $WORKTIME_DIR/scripts/uprecords-sync.fish
end

function worktime::supersync
    set -l failed 0
    set -l first_sync_failed 0
    worktime::supersync_sync sync_quotes
    if test $status -ne 0
        set failed 1
        set first_sync_failed 1
    end
    taskwarrior::invoke
    or set failed 1
    if functions -q worktime::uprecords::darwin::collect
        worktime::uprecords::darwin::collect
        or set failed 1
        worktime::uprecords::darwin::import
        or set failed 1
    end
    if test $first_sync_failed -eq 0
        worktime::supersync_sync no_sync_quotes
        or set failed 1
    end
    return $failed
end

function worktime::wisdom_reminder
    if test -f $WORKTIME_DIR/work-wisdoms.md
        sed -n '/^\* / { s/\* //; p; }' $WORKTIME_DIR/work-wisdoms.md | sort -R | head -n 1
    end
end

abbr -a cdworktime "cd $WORKTIME_DIR"

# New system (timesamurai) -- these are the ones to use day to day.
abbr -a wt 'timesamurai work'
abbr -a wtedit 'worktime::edit'
abbr -a wtreport 'worktime::report'
abbr -a wtadd 'worktime::add'
abbr -a wtlogin 'worktime::login'
abbr -a wtlogout 'worktime::logout'
abbr -a wtstatus 'worktime::status'
abbr -a wtsync 'worktime::sync'
abbr -a wtf 'timesamurai work report'

abbr -a wl 'task add +work'
abbr -a ql 'task add +personal'
abbr -a pl 'task add +personal'
