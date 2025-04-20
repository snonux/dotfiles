set -x SYNC_STAMP_FILE ~/.sync.last

function sync::is_it_time_to_sync
    set -l max_age 86400
    set -l now (date +%s)
    if test -f $SYNC_STAMP_FILE
        set -l diff (math $now - (cat $SYNC_STAMP_FILE))
        if test $diff -lt $max_age
            return 0
        end
    end
    echo 'It is time to run sync!!!'
end

# Only sync the HabitsAndQuotes when it's asked for via function parameter
function sync::worktime
    set -l worktime_dir ~/git/worktime

    if not test -d $worktime_dir
        echo "Warning: Directory $worktime_dir does not exist"
        return 1
    end
    cd $worktime_dir

    if test (count $argv) -gt 0 -a $argv[1] = sync_quotes
        if test -d ~/Notes/HabitsAndQuotes
            echo "" >work-wisdoms.md.tmp
            for notes in ~/Notes/HabitsAndQuotes/{Productivity,Mentoring}.md
                grep '^\* ' $notes >>work-wisdoms.md.tmp
            end
            sort -u work-wisdoms.md.tmp >work-wisdoms.md
            rm work-wisdoms.md.tmp
            git add work-wisdoms.md
            grep '^\* ' ~/Notes/HabitsAndQuotes/Exercise.md >exercises.md
            git add exercises.md
        end
    end

    find . -name '*.txt' -exec git add {} \;
    find . -name '*.json' -exec git add {} \;
    git commit -a -m sync

    git pull origin master
    git push origin master

    cd -
end

function sync::uprecords
    set -l uprecords_dir ~/git/uprecords
    set -l uprecords_repo git@codeberg.org:snonux/uprecords.git

    if not test -d $uprecords_dir
        git clone $uprecords_repo $uprecords_dir
        cd $uprecords_dir
    else
        cd $uprecords_dir
        git pull
    end

    make update
    git commit -a -m Update
    git push
    cd -
end

function sync::taskwarrior
    if test -f ~/scripts/taskwarriorfeeder.rb
        ruby ~/scripts/taskwarriorfeeder.rb
    else
        echo "No taskwarrior feeder script, skipping"
    end

    taskwarrior::export
    taskwarrior::import
end

function sync
    sync::worktime sync_quotes
    sync::taskwarrior
    sync::worktime no_sync_quotes
    sync::uprecords

    if which gos >/dev/null
        gos
    end

    date +%s >$SYNC_STAMP_FILE.tmp
    mv $SYNC_STAMP_FILE.tmp $SYNC_STAMP_FILE
end
