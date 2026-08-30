set -gx WORKTIME_DIR ~/git/worktime

if test (uname) = Darwin -a ! -f ~/.wtloggedin
    echo "Warn: Not logged in, run wtlogin"
end

function worktime
    ruby $WORKTIME_DIR/worktime.rb $argv
end

# We run both trackers side by side for a while: worktime.rb stays the source
# of truth while timesamurai records the same events into its own JSONL store
# (~/git/worktime/timesamuraidb), so the two can be compared before cutting
# over. timesamurai accepts worktime.rb's own flags, so mirroring is a literal
# echo of the arguments.
#
# This must never break the Ruby path, so a missing binary is skipped and a
# failure only warns. Set WORKTIME_MIRROR=0 to switch mirroring off.
#
# It deliberately never runs `timesamurai work export`: that rewrites
# db.<host>.json from the JSONL store and would clobber whatever worktime.rb
# has written since -- exactly what parallel tracking must not do. The two
# stores stay independent until the trial ends.
function worktime::mirror
    if test "$WORKTIME_MIRROR" = 0
        return 0
    end
    if not type -q timesamurai
        return 0
    end
    if not timesamurai work $argv >/dev/null 2>&1
        echo "worktime: timesamurai mirror failed for '$argv' (worktime.rb unaffected)" >&2
    end
    return 0
end

# Compare the two reports. During parallel running the useful signal is not a
# second 4600-line dump but whether the trackers still agree; a divergence is
# the thing worth acting on.
function worktime::report::compare
    if test "$WORKTIME_MIRROR" = 0
        return 0
    end
    if not type -q timesamurai
        return 0
    end

    set -l ruby_out (mktemp)
    set -l ts_out (mktemp)
    worktime --report >$ruby_out 2>/dev/null
    timesamurai work report >$ts_out 2>/dev/null

    if cmp -s $ruby_out $ts_out
        echo "timesamurai: agrees with worktime.rb"
    else
        echo "timesamurai: REPORTS DIVERGE -- run wtdiff to see how" >&2
    end

    rm -f $ruby_out $ts_out
    return 0
end

# Show exactly how the two reports differ (worktime.rb on the left).
function worktime::report::diff
    if not type -q timesamurai
        echo "timesamurai is not installed" >&2
        return 1
    end

    set -l ruby_out (mktemp)
    set -l ts_out (mktemp)
    worktime --report >$ruby_out 2>/dev/null
    timesamurai work report >$ts_out 2>/dev/null

    diff -u $ruby_out $ts_out; or true
    rm -f $ruby_out $ts_out
    return 0
end

function worktime::sync
    cd $WORKTIME_DIR
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

function worktime::report
    if test -f ~/.wtloggedin
        if test -f ~/.wtmaster
            worktime --report | tee $WORKTIME_DIR/report.txt
        else
            worktime --report
        end
        worktime::report::compare
        worktime::wisdom_reminder
    end
end

function worktime::add
    set -l seconds $argv[1]
    set -l what $argv[2]
    set -l descr $argv[3]
    set -l epoch (date +%s)

    if test -z "$what"
        set what work
    end

    if test -z "$descr"
        worktime --add $seconds --epoch $epoch --what $what
        worktime::mirror --add $seconds --epoch $epoch --what $what
    else
        worktime --add $seconds --epoch $epoch --what $what --descr "$descr"
        worktime::mirror --add $seconds --epoch $epoch --what $what --descr "$descr"
    end

    worktime::report
end

# BROKEN, and left broken on purpose: `--log` is ambiguous between --login and
# --logout, so worktime.rb rejects it and this function has never recorded
# anything. $seconds is read but never passed, which suggests it was meant to
# be a copy of worktime::add. Guessing at the intent would silently start
# writing time entries, so it is flagged here for a human to decide instead.
# Nothing is mirrored into timesamurai until it does something.
function worktime::log
    set -l seconds $argv[1]
    set -l what $argv[2]
    set -l epoch (date +%s)

    if test -z "$what"
        set what work
    end

    worktime --log --epoch $epoch --what $what
    worktime::report
end

function worktime::login
    set -l what $argv[1]
    if test -z "$what"
        set what work
    end
    touch ~/.wtloggedin
    worktime --login --what $what
    worktime::mirror --login --what $what
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

    worktime --logout --what $what
    worktime::mirror --logout --what $what
    worktime::report
end

function worktime::status
    worktime::report

    if test -f ~/.wtloggedin
        echo "You are logged in"
        set -l num_worklog (ls $WORKTIME_DIR | grep wl- | wc -l)
        if test $num_worklog -gt 0
            echo "$num_worklog entries in the worklog in $WORKTIME_DIR/wl-*"
        end
    else
        echo "You are not logged in"
    end

    if type -q timesamurai
        echo -n "timesamurai: "
        timesamurai work status 2>/dev/null; or echo "unavailable"
    end
end

abbr -a cdworktime "cd $WORKTIME_DIR"
abbr -a wt worktime
abbr -a wtedit 'worktime --edit'
abbr -a wtreport 'worktime --report'
abbr -a wtadd 'worktime::add'
abbr -a wtlog 'worktime::log'
abbr -a wtlogin 'worktime::login'
abbr -a wtlogout 'worktime::logout'
abbr -a wtstatus 'worktime::status'
abbr -a wtsync 'worktime::sync'
abbr -a wtf 'worktime --report'
abbr -a wtdiff 'worktime::report::diff'
abbr -a wtts 'timesamurai work'
abbr -a wl 'task add +work'
abbr -a ql 'task add +personal'
abbr -a pl 'task add +personal'
