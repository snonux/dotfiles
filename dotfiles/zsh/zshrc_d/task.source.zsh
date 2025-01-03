if [[ -f ~/.taskrc && -f ~/.task.enable ]]; then
    export TASK_STAMP_FILE=~/.tasksync.last
    export WORKTIME_DIR=~/git/worktime

    alias t='task'

    local date=date
    if where gdate &>/dev/null; then
        date=gdate
    fi

    _task::config () {
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
            return
        fi
        ruby ~/scripts/taskwarriorfeeder.rb
    }

    if [ -d ~/Notes/GosDir ]; then
        task::gos::compose () {
            local -r compose_file=~/Notes/GosDir/$(date +%s).txt
            hx $compose_file.tmp && mv $compose_file.tmp $compose_file
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
        alias cdgos='cd ~/Notes/GosDir'
    else
        task::gos::run () {
            :
        }
    fi

    task::due () { 
        task active 2>/dev/null
        task status:pending due.before:now
    }
    alias tdue=task::due

    task::due::count () {
        local -i due_count=$(task status:pending due.before:now count)
        if [ $due_count -gt 0 ]; then
            echo "There are $due_count tasks due!"
        fi
    }
    task::due::count

    task::done () {
        task::select "$1"
        task $TASK_ID
        if _task::config "Mark task $TASK_ID as done"; then
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
        date +%Y-%m-%d --date "$due_days days"
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
    alias tfind=task::fuzzy::find

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

    _task::set_import_export_tags () {
        if [ $(uname) = Darwin ]; then
            export TASK_IMPORT_TAG=work
            export TASK_EXPORT_TAG=personal
        else
            export TASK_IMPORT_TAG=personal
            export TASK_EXPORT_TAG=work
        fi
    }

    task::export () {
        _task::set_import_export_tags

        local -i count=$(task +$TASK_EXPORT_TAG status:pending count)
        if [ $count -eq 0 ]; then
            return
        fi

        echo "Exporting $count tasks to $TASK_EXPORT_TAG"
        task +$TASK_EXPORT_TAG status:pending export > \
            "$WORKTIME_DIR/tw-$TASK_EXPORT_TAG-export-$(date +%s).json"
        yes | task +$TASK_EXPORT_TAG status:pending delete
    }

    task::import () {
        _task::set_import_export_tags
        find $WORKTIME_DIR -name "tw-$TASK_IMPORT_TAG-export-*.json" \
            | while read -r import; do
                task import $import
                rm $import
              done  
    }    

    task::sync () {
        task::rubyize
        task::export

        if [ -d $WORKTIME_DIR ]; then
            cd $WORKTIME_DIR
            git pull
            git add *.txt *.json
            git commit -a -m 'do stuff'
            git push
            cd -
        fi

        task::import
        task::gos::run

        local -i now=$(date +'%s')
        echo $now > $TASK_STAMP_FILE
    }
    alias tsync=task::sync

    task::is_it_time_to_sync () {
        local -i max_age=86400
        local -i now=$(date +'%s')

        if [ -f $TASK_STAMP_FILE ]; then
            local -i diff=$(( now - $(cat $TASK_STAMP_FILE) ))
            if [ $diff -lt $max_age ]; then
                return 0
            fi
        fi

        echo 'It is time to run tsync!!!'
    }
    task::is_it_time_to_sync
fi
