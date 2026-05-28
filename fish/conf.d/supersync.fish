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

    if test -f ~/go/bin/gitsyncer
        ~/go/bin/gitsyncer sync bidirectional --auto-create-releases --create-repos --throttle && ~/go/bin/gitsyncer showcase
    end
    if test $status -eq 0
        echo $now >$enable_file
    end
end

function supersync::prompts
    # Since files might have been added and/or modified withoug being
    # committed to git yet.
    if test -d ~/git/dotfiles/prompts
        # For my Linux hosts
        cd ~/git/dotfiles/prompts
        find . -type f -name \*.md | xargs git add
        find . -type f -name \*.md | xargs git commit -m 'update prompts'
        git push
        cd -
    else if test -d ~/git/helpers/prompts
        # For my Mac host
        cd ~/git/helpers/prompts
        find . -type f -name \*.md | xargs git add
        find . -type f -name \*.md | xargs git commit -m 'update prompts'
        git push
        cd -
    end
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
    # update::tools

    date +%s >$SUPERSYNC_STAMP_FILE.tmp
    mv $SUPERSYNC_STAMP_FILE.tmp $SUPERSYNC_STAMP_FILE
end

abbr -a supersynct 'supersync; track'
