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

    worktime::wisdom_reminder () {
        if [ $WORKTIME_DIR/work-wisdoms.md ]; then
            sed -n '/^\* / { s/\* //; p; }' $WORKTIME_DIR/work-wisdoms.md | sort -R | head -n 1
        fi
    }

    worktime::report () {
        if [ -f ~/.wtloggedin ]; then
            if [ -f ~/.wtmaster ]; then
                # Avoiding merge conflicts
                worktime --report | tee $WORKTIME_DIR/report.txt
            else
                worktime --report 
            fi
            worktime::wisdom_reminder
        fi
    }
    alias wtreport=worktime::report
    # wtreport force
    alias wtf='worktime --report'

    worktime::sync () {
        cd $WORKTIME_DIR
        echo > work-wisdoms.md.tmp
        for notes in ~/Notes/HabitsAndQuotes/{Productivity,Mentoring}.md; do  
            grep '^\* ' $notes >> work-wisdoms.md.tmp
        done
        sort -u work-wisdoms.md.tmp > work-wisdoms.md
        rm work-wisdoms.md.tmp
        git add work-wisdoms.md 

        find . -name \*.txt -exec git add {} \;
        git add db.*.json
        git commit -a -m sync
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
        worktime::wisdom_reminder
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
            local -i num_worklog=$(ls $WORKTIME_DIR | grep wl- | wc -l)
            if [ $num_worklog -gt 0 ]; then
                echo "$num_worklog entries in the worklog"
            fi
        else
            echo "You are not logged in"
        fi
    }
    alias wtstatus=worktime::status

    worktime::log::personal::quick () {
        cd $WORKTIME_DIR
        echo "$@" > "pl-$(date +%s).txt"
        git add pl-*.txt
        git commit -m "Add personal log" pl-*.txt
        cd -
    }
    alias ql=worktime::log::personal::quick
    alias pl=worktime::log::personal::quick

    worktime::log::work () {
        cd $WORKTIME_DIR

        if [ -z "$@" ]; then
            grep . wl-*.txt 2>/dev/null
            cd -
             return
        elif [ "$@" = clear ]; then
            git rm wl-*.txt 2>/dev/null
            git commit -m 'Cleaning up work log'
            cd -
            return
        fi
            
        cd $WORKTIME_DIR
        echo "$@" > "wl-$(date +%s).txt"
        git add wl-*.txt
        git commit -m "Add work log" wl-*.txt
        cd -
    }
    alias wl=worktime::log::work

    # For collecting my skills, e.g. for my CV
    worktime::skill::add () {
        cd $WORKTIME_DIR
        echo "$@" >> skills.txt
        sort -u skills.txt | tee skills.txt.new
        mv skills.txt.new skills.txt
        git add skills.txt
        git commit -m "Add skill" skills.txt
        cd -
    }

    alias skilladd=worktime::skill::add
fi
