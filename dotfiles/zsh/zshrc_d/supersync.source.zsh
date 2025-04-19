set -x SUPERSYNC_STAMP_FILE ~/.supersync.last

function supersync::is_it_time_to_sync
    set -l max_age 86400
    set -l now (date +%s)
    if test -f $SUPERSYNC_STAMP_FILE
        set -l diff (math $now - (cat $SUPERSYNC_STAMP_FILE))
        if test $diff -lt $max_age
            return 0
        end
    end
    echo 'It is time to run supersync!!!'
end

function supersync::sync
    worktime::sync
    uprecords::sync
    task::sync
    if test -f $GOS_BIN
        gos
    end
    date +%s > $SUPERSYNC_STAMP_FILE.tmp
    mv $SUPERSYNC_STAMP_FILE.tmp $SUPERSYNC_STAMP_FILE
end

alias supersync=supersync::sync
