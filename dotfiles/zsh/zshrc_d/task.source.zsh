if [[ -f ~/.taskrc && -f ~/.task.enable ]]; then
    alias t='task'

    local date=date
    if where gdate &>/dev/null; then
        date=gdate
    fi

    task::_confirm () {
        local -r message="$1"; shift
        if [ "$TASK_AUTO_CONFIRM" = yes ]; then
            echo "Auto confirming"
            return 0
        fi
        # bash:
        # read -p "$message? (y/n)" answer
        # zsh:
        read "answer?$message? (y/n)"
        if [ "$answer" = y ]; then
            return 0
        else
            return 1
        fi
    }

    task::rubyize () {
        if [ ! -f ~/scripts/taskwarriorfeeder.rb ]; then
            echo 'taskwarrior feeder script not installed!' >&2
            return
        fi
        ruby ~/scripts/taskwarriorfeeder.rb
    }

    task::gos::compose () {
        hx ~/Notes/GosDir/$(date +%s).txt
    }
    alias gosc=task::gos::compose

    task::gos::run () {
        if [ ! -f ~/go/bin/gos ]; then
            echo "gos not installed?"
            return
        fi
        ~/go/bin/gos -gosDir ~/Notes/GosDir
    }
    alias gosr=task::gos::run

    task::due () { 
        task active 2>/dev/null
        local -i due_count=$(task status:pending due.before:now count)
        if [ $due_count -gt 0 ]; then
            echo "There are $due_count tasks due!"
        fi
    }
    alias tdue=task::due
    task::due

    task::done () {
        task::select "$1"
        task $TASK_ID
        if task::_confirm "Mark task $TASK_ID as done"; then
            task $TASK_ID done
            task::due
        fi
    }
    alias tdone=task::done

    task::edit () {
        task::select "$1"
        task $TASK_ID edit
    }
    alias tedit=task::edit

    task::del () {
        task::select "$1"
        task $TASK_ID delete
    }
    alias tdel=task::del

    task::start () {
        task::select "$1"
        task $TASK_ID start
    }
    alias tstart=task::start

    task::stop () {
        task::select "$1"
        task $TASK_ID stop
    }
    alias tstop=task::stop

    task::annotate () {
        task::select "$1"; shift
        task $TASK_ID annotate "$@"
    }
    alias tanon=task::annotate

    task::random::due_date () {
        local -i seed="$1"
        local -i due_days=$(( ($RANDOM + $seed) % 30))
        $date +%Y-%m-%d --date "$due_days days"
    }

    task::randomize () {
        task::select "$1"
        local -i seed="$2"

        echo 'Tasks without due date:'
        task due:

        echo "Setting random due date for task $TASK_ID"
        task $TASK_ID modify due:$(task::random::due_date $seed)
    }
    alias trand=task::randomize

    task::add () {
        task add "$@" due:$(task::random::due_date)
    }
    alias a=task::add

    task::add::log () {
        task add +log "$@" due:$(task::random::due_date)
    }
    alias log=task::add::log 

    task::add::track () {
        task add +track "$@" due:eow
    }
    alias track=task::add::track

    task::is_it_time_to_sync () {
        readonly stamp_file=~/.tasksync.last

        local -i max_age=86400
        local -i now=$($date +'%s')

        if [ -f $stamp_file ]; then
            local -i diff=$(( now - $(cat $stamp_file) ))
            if [ $diff -lt $max_age ]; then
                return 0
            fi
        fi

        echo 'It is time to run tsync!!!'
    }

    task::sync () {
        task::rubyize
        task::gos::run

        if [ -d ~/git/worktime ]; then
            cd ~/git/worktime
            git pull
            git add *.txt *.json
            git commit -a -m 'add stuff'
            git push
            cd -
        fi
        echo $now > $stamp_file
    }
    alias tsync=task::sync

    task::dice () {
        local -r filter=$1
        TASK_ID=$(task $filter ready | sort -R | sed -n '/^[0-9]/ { p; q; }' | cut -d' ' -f1)
        task $TASK_ID
    }
    alias tdice=task::dice

    task::dice::next () {
        if [ -z "$TASK_ID" ]; then
            echo "No diced task ID!"
            return 1
        fi
        task done $TASK_ID
        task::dice
    }
    alias tnext=task::dice::next

    task::fuzzy::_select () {
        sed -n '/^[0-9]/p' | sort -rn | fzf | cut -d' ' -f1
    }

    task::fuzzy::find () {
        TASK_ID=$(task ready | task::fuzzy::_select)
    }
    alias tfind=task::fuzzy::

    task::select () {
        local -r task_id="$1"
        if [ ! -z "$task_id" ]; then
            TASK_ID="$task_id"
        fi
        if [[ "$TASK_ID" = '-' || -z "$TASK_ID" ]]; then
            task::fuzzy::find
        fi
    }
    alias tsel=task::select

    task::fuzzy::due () {
        local -r flag="$1"

        TASK_ID=$(task limit:0 due.before:$($date +%Y-%m-%d --date '7 days') |
            sed -E '/^$/d; /^[[:digit:]]+ tasks/d' |
            task::fuzzy::_select)

        if [ "$flag" != silent ]; then
            task $TASK_ID
        fi
    }
    alias fdue=task::fuzzy::due
    alias fdone='task::fuzzy::due && task::done'

    task::export::danger () {
        if [ ! -d ~/git/worktime ]; then
            echo 'No worktime directory'
            return
        fi

        task export > ~/git/worktime/taskwarrior-export-"$(hostname)-$(date +%s)".json
        echo 'exported database'
        task::sync
        task delete
    }

    task::is_it_time_to_sync
fi
