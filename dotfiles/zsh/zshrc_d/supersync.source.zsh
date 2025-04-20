export SUPERSYNC_STAMP_FILE=~/.supersync.last

supersync::is_it_time_to_sync () {
    local max_age=86400
    local now=$(date +%s)
    if [[ -f $SUPERSYNC_STAMP_FILE ]]; then
        local diff=$(( now - $(cat $SUPERSYNC_STAMP_FILE) ))
        if [[ $diff -lt $max_age ]]; then
            return 0
        fi
    fi
    echo 'It is time to run supersync!!!'
}

supersync::sync () {
    worktime::sync
    uprecords::sync
    task::sync
    if [[ -f $GOS_BIN ]]; then
        gos
    fi
    date +%s > $SUPERSYNC_STAMP_FILE.tmp
    mv $SUPERSYNC_STAMP_FILE.tmp $SUPERSYNC_STAMP_FILE
}

alias supersync='supersync::sync'
