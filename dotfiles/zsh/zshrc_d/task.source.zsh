if [[ -f ~/.taskrc && -f ~/.task.enable ]]; then
    alias t=task
    alias j='task add +journal'

    task::rakurize () {
        if [ -d ~/Notes ]; then
            cd ~/Notes
            raku ~/scripts/taskwarriorfeeder.raku
            cd -
        fi
    }

    alias tdue='task active;task due.before:14day long'
    sh -c 'task active;task due.before:14day long 2>/dev/null; exit 0'

    task::random::due_date () {
        local -i due_days=$(($RANDOM % 365))
        date +%Y-%m-%d --date "$due_days days"
    }

    task::randomize () {
        local -i task_id="$1"; shift

        echo 'Tasks without due date:'
        task due:

        echo "Setting random due date for task $task_id"
        task $task_id modify due:$(task::random::due_date)
    }

    task::add () {
        task add "$@" due:$(task::random::due_date)
    }
    alias a=task::add

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
    alias tsync='task::sync force'

    task::sync 
fi
