if [[ -f ~/.taskrc && -f ~/.task.enable ]]; then
    alias t='task'

    export DATE=$(command -v gdate || echo date)
    if ! $DATE --version | grep -q -v GNU; then
        echo 'GNU Date not installed'
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
        $DATE +%Y-%m-%d --date "$due_days days"
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
        task add priority:L "$@"
    }
    alias a=task::add

    task::add::log () {
        task add priority:L +log "$@"
    }
    alias log=task::add::log 

    task::add::track () {
      if [ "$#" -gt 0 ]; then
        task add priority:L +personal +track "$@" due:eow
      else
        vit +track
      fi
    }
    alias track=task::add::track
    alias T=task::add::track

    task::add::standup() {
      if [ "$#" -gt 0 ]; then
        task add priority:L +work +standup "$@" due:3days
      else
        vit +standup
      fi
    }
    alias standup=task::add::standup
    # Virtual standup
    alias V=task::add::standup

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

        TASK_ID=$(task limit:0 due.before:$($DATE +%Y-%m-%d --date '7 days') |
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
        find $WORKTIME_DIR -name "tw-$(hostname)-export-*.json" \
            | while read -r import; do
                task import $import
                rm $import
              done  
    }    

    task::sync () {
        if [ -f ~/scripts/taskwarriorfeeder.rb ]; then
            ruby ~/scripts/taskwarriorfeeder.rb
        fi
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
    }
    alias tsync=task::sync
fi
