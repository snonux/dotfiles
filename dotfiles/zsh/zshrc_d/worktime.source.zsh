WORKTIME_DIR=~/git/worktime

if [ -d $WORKTIME_DIR ]; then
    alias cdworktime="cd $WORKTIME_DIR"
    if [[ $(uname) = Darwin && ! -f ~/.wtloggedin ]]; then
        echo "Warn: Not logged in, run wtlogin"
    fi

    worktime () {
        ruby $WORKTIME_DIR/worktime.rb $@
    }
    alias wt=worktime
    alias wtedit='worktime --edit'

    worktime::deepwork_reminder () {
        if [ $WORKTIME_DIR/DeepWork.md ]; then
            sed -n '/^\* / { s/\* //; p; }' $WORKTIME_DIR/DeepWork.md | sort -R | head -n 1
        fi
    }

    worktime::report () {
        if [ $(uname) = Darwin ]; then
            worktime --report | tee $WORKTIME_DIR/report.txt
            worktime::deepwork_reminder
        fi
    }
    alias wtreport=worktime::report

    worktime::sync () {
        cd $WORKTIME_DIR
        if [ -f ~/Notes/HabitsAndQuotes/DeepWork.md ]; then
            cp ~/Notes/HabitsAndQuotes/DeepWork.md .
            git add DeepWork.md 
        fi

        git add db.*.json
        git commit -a -m 'sync worktime'
        git pull origin master
        git push origin master
        cd -
    }
    alias wtsync=worktime::sync

    worktime::add () {
        local -r seconds=$1
        local what=$2
        local -r descr="$3"
        local -r epoch=$($GDATE +%s)

        if [ -z "$what" ]; then
            what=work
        fi

        if [ -z "$descr" ]; then
            worktime --add $seconds --epoch $epoch --what $what
        else
            worktime --add $seconds --epoch $epoch --what $what --descr "$descr"
        fi
        worktime::report
    }
    alias wtadd=worktime::add

    worktime::log () {
        local -r seconds=$1
        local what=$2
        local -r epoch=$($GDATE +%s)

        if [ -z "$what" ]; then
            what=work
        fi

        worktime --log --epoch $epoch --what $what
        worktime::report
    }
    alias wtlog=worktime::log

    worktime::login () {
        local what=$1
        if [ -z "$what" ]; then
            what=work
        fi

        touch ~/.wtloggedin
        worktime --login --what $what
        worktime::deepwork_reminder
    }
    alias wtlogin=worktime::login

    worktime::logout () {
        local what=$1
        local sync=$2

        if [ -z "$what" ]; then
            what=work
        fi

        if [ -f ~/.wtloggedin ] ; then
            rm ~/.wtloggedin
        fi

        worktime --logout --what $what
        worktime::report
        if [ ! -z "$sync" ]; then
            worktime::sync
            worktime::report
        fi
    }
    alias wtlogout=worktime::logout

    worktime::status () {
        worktime::report

        if [ -f ~/.wtloggedin ]; then
            echo "You are logged in"
            if [ ! -f $WORKTIME_DIR/worklog.txt ]; then
                return
            fi
            echo 'Entries in the worklog (wle to edit):'
            wc -l $WORKTIME_DIR/worklog.txt
        else
            echo "You are not logged in"
        fi
    }
    alias wtstatus=worktime::status

    worktime::quicklog () {
        cd $WORKTIME_DIR
        echo "$@" > "ql-$(date +%s).txt"
        git add ql-*.txt
        git commit -m "Add quicklog" *.txt
        cd -
    }
    alias ql=worktime::quicklog

    worktime::worklog () {
        cd $WORKTIME_DIR
        date >> worklog.txt
        echo "$@" >> worklog.txt
        echo >> worklog.txt
            git add worklog.txt
        git commit -m "Add worklog" *.txt
        cd -
    }
    alias wl=worktime::worklog

    worklog::edit () {
        cd $WORKTIME_DIR
        $EDITOR worklog.txt
        git add worklog.txt
        git commit -m "Edi worklog" *.txt
        cd -
    }
    alias wle=worklog::edit
fi
