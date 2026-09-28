set -x SUPERSYNC_STAMP_FILE ~/.supersync.last

function supersync::gitsyncer
    set enable_file ~/.gitsyncer_enable
    set now (date +%s)
    set weekly_interval (math 7 \* 24 \* 60 \* 60)

    if not test -f $enable_file
        # echo Gitsyncer is not enabled
        return
    end

    set last_run (cat $enable_file)
    if test (math $now - $last_run) -lt $weekly_interval
        return
    end

    test -f ~/go/bin/gitsyncer; or return 1
    ~/go/bin/gitsyncer sync bidirectional --backup --auto-create-releases --create-repos --throttle; or return 1
    ~/go/bin/gitsyncer showcase; or return 1
    echo $now >$enable_file
end

function supersync::prompts
    # Since files might have been added and/or modified without being
    # committed to git yet.
    # On Darwin (macOS) the public dotfiles repo is pull-only, so prompts are
    # pushed to ~/git/helpers/prompts instead. The dotfiles/prompts branch is
    # only ever pushed from Linux hosts.
    set -l prompts_dir
    if test -d ~/git/dotfiles/prompts -a (uname) != Darwin
        set prompts_dir ~/git/dotfiles/prompts
    else if test -d ~/git/helpers/prompts
        set prompts_dir ~/git/helpers/prompts
    else
        return
    end

    git -C $prompts_dir add -A -- '*.md'; or return 1
    git -C $prompts_dir diff --cached --quiet -- '*.md'
    set -l diff_status $status
    if test $diff_status -gt 1
        return $diff_status
    end
    if test $diff_status -eq 1
        git -C $prompts_dir commit -m 'update prompts' -- '*.md'; or return 1
    end
    git -C $prompts_dir push
end

function supersync::is_it_time_to_sync
    set -l max_age 86400
    set -l now (date +%s)
    if test -f $SUPERSYNC_STAMP_FILE
        set -l diff (math $now - (cat $SUPERSYNC_STAMP_FILE))
        if test $diff -lt $max_age
            return 0
        end
    end
    read -P "It's time to run supersync! Run it? (y/n) " answer; and test "$answer" = y; and supersync
end

function supersync
    if test -f ~/.supersync_disable
        echo Supersync is disabled
        return
    end

    worktime::supersync
    supersync::prompts

    if test -f ~/.gos_enable
        if test -f ~/go/bin/gos
            # Go social media tool
            ~/go/bin/gos
        end
        if test -f ~/go/bin/snonux
            snonux::sync
        end
    end

    supersync::gitsyncer
    tmputils::clean
    update::tools

    date +%s >$SUPERSYNC_STAMP_FILE.tmp
    mv $SUPERSYNC_STAMP_FILE.tmp $SUPERSYNC_STAMP_FILE
end

abbr -a supersynct 'supersync; track'
