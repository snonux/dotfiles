if [[ -f ~/.taskrc && -f ~/.task.enable ]]; then
    alias t='task'
    alias j='task add +journal'

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

    task::rakurize () {
        if [ -d ~/Notes ]; then
            cd ~/Notes
            raku ~/scripts/taskwarriorfeeder.raku
            cd -
        fi
    }

    task::due () { 
        task active
        task due.before:$(date +%Y-%m-%d --date '7 days')
    }
    alias tdue=task::due
    task::due

    task::done () {
        if [ ! -z "$1" ]; then
            task_id=$1
        fi
        task $task_id
        if task::_confirm "Mark task $task_id as done"; then
            task $task_id done
            task::due
        fi
    }
    alias tdone=task::done

    task::del () {
        if [ ! -z "$1" ]; then
            task_id=$1
        fi
        task $task_id delete
    }
    alias tdel=task::del

    task::start () {
        if [ ! -z "$1" ]; then
            task_id=$1
        fi
        task $task_id start
    }
    alias tstart=task::start

    task::random::due_date () {
        local -i seed="$1"
        local -i due_days=$(( ($RANDOM + $seed) % 365))
        date +%Y-%m-%d --date "$due_days days"
    }

    task::randomize () {
        local -i task_id="$1"; shift
        local -i seed="$1"
        if [ ! -z "$1" ]; then
            task_id=$1
        fi
        task $task_id

        echo 'Tasks without due date:'
        task due:

        echo "Setting random due date for task $task_id"
        task $task_id modify due:$(task::random::due_date $seed)
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

    task::sync () {
        readonly force="$1"
        readonly stamp_file=~/.tasksync.last

        local -i max_age=86400
        local -i now=$(date +'%s')

        if [[ "$force" != 'force' && -f $stamp_file ]]; then
            local -i diff=$(( now - $(cat $stamp_file) ))
            if [ $diff -lt $max_age ]; then
                return 0
            fi
        fi

        task::rakurize

        for remote in git@git1.buetow.org git@git2.buetow.org; do
            echo "Syncing task status to $remote"
            rsync --delete -av ~/.task/ $remote:.task
        done

        echo $now > $stamp_file
    }
    alias tsync='task::sync force; task::due'

    task::dice () {
        local -r filter=$1
        task_id=$(task $filter ready | sort -R | sed -n '/^[0-9]/ { p; q; }' | cut -d' ' -f1)
        task $task_id
    }
    alias tdice=task::dice

    task::dice::next () {
        if [ -z "$task_id" ]; then
            echo "No diced task ID!"
            return 1
        fi
        task done $task_id
        task::dice
    }
    alias tnext=task::dice::next

    task::fuzzy::_select () {
        sed -n '/^[0-9]/p' | sort -rn | fzf | cut -d' ' -f1
    }

    task::fuzzy::find () {
        task_id=$(task ready | task::fuzzy::_select)
        task $task_id
    }
    alias tfind=task::fuzzy::find

    task::fuzzy::due () {
        task_id=$(task limit:0 due.before:$(date +%Y-%m-%d --date '7 days') |
            sed -E '/^$/d; /^[[:digit:]]+ tasks/d' |
            task::fuzzy::_select)
        task $task_id
    }
    alias fdue=task::fuzzy::due

    task::sync 
fi
