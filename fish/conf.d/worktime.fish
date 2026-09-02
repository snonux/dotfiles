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

    if test (count $argv) -gt 0 -a $argv[1] = sync_quotes
        if test -d ~/Notes/HabitsAndQuotes
            echo "" >work-wisdoms.md.tmp
            for notes in ~/Notes/random/{Productivity,Mentoring}.md
                grep '^\* ' $notes >>work-wisdoms.md.tmp
            end
            sort -u work-wisdoms.md.tmp >work-wisdoms.md
            rm work-wisdoms.md.tmp
            git add work-wisdoms.md
            grep '^\* ' ~/Notes/random/Exercise.md >exercises.md
            git add exercises.md
        end
    end

    find . -name '*.txt' -exec git add {} \;
    find . -name '*.json' -exec git add {} \;
    find . -name '*.csv' -exec git add {} \;
    find . -name '*.jsonl' -exec git add {} \;
    git commit -a -m sync

    git pull origin master
    git push origin master

    cd -
end

# uprecords collect/import helpers live in the (private) worktime repo so that
# host-specific details stay out of the public dotfiles repo. The functions
# guard internally (collect on Darwin, import on earth).
if test -f $WORKTIME_DIR/scripts/uprecords-sync.fish
    source $WORKTIME_DIR/scripts/uprecords-sync.fish
end

function worktime::supersync
    worktime::supersync_sync sync_quotes
    taskwarrior::invoke
    if functions -q worktime::uprecords::darwin::collect
        worktime::uprecords::darwin::collect
        worktime::uprecords::darwin::import
    end
    worktime::supersync_sync no_sync_quotes
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
