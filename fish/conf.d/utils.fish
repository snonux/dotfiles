function fullest_i
    df -i | sort -n -k 5
end

function fullest_h
    df -h | sort -n -k 5
end

function usortn
    sort | uniq -c | sort -n
end

function asum
    awk '{ sum += $1 } END { print sum }'
end

function stop
    set -l service $argv[1]
    sudo service $service stop $argv
end

function start
    set -l service $argv[1]
    sudo service $service start $argv
end

function restart
    set -l service $argv[1]
    sudo service $service restart $argv
end

function statuss
    set -l service $argv[1]
    sudo service $service status $argv
end

function loop
    set -l sleep 10
    if set -q SLEEP
        set sleep $SLEEP
    end
    echo "sleep is $sleep" 1>&2
    while true
        $argv
        sleep $sleep
    end
end

function f
    find . -iname "*$argv*"
end

function random
    set -l upto $argv[1]
    set -l random (math $RANDOM % $upto)
    echo "Sleeping $random seconds"
    sleep $random
end

function _dedup_file --argument-names file keep_backup
    # Keep the output beside the source so the final move stays on one filesystem.
    # collect keeps embedded newlines while removing mktemp's final newline.
    set -l output (sudo mktemp -- "$file.dedup.XXXXXX" | string collect)
    or return 1
    if not sudo cp -p -- $file $output
        sudo rm -f -- $output
        return 1
    end

    awk '{ if (line[$0] != 42) { print $0 }; line[$0] = 42; }' $file | sudo tee -- $output >/dev/null
    set -l conversion_status $pipestatus
    if test $conversion_status[1] -ne 0; or test $conversion_status[2] -ne 0
        sudo rm -f -- $output
        return 1
    end

    # A unique backup makes every run recoverable, including reruns with old backups.
    set -l backup (sudo mktemp -- "$file.dedupbak.XXXXXX" | string collect)
    or begin
        sudo rm -f -- $output
        return 1
    end
    if not sudo cp -Pp -- $file $backup
        sudo rm -f -- $output $backup
        return 1
    end

    if not sudo mv -- $output $file
        sudo rm -f -- $output
        return 1
    end

    wc -l -- $file $backup
    if test $keep_backup = yes
        # gzip refuses symlinks; retain the link to the original target.
        if not test -L $backup
            sudo gzip --best -- $backup &
        end
    else
        sudo rm -v -- $backup
        or return 1
    end
    return 0
end

function dedup
    set -l file $argv[1]
    if test -z "$file"
        awk '{ if (line[$0] != 42) { print $0 }; line[$0] = 42; }'
    else
        _dedup_file $file yes
    end
end

function dedup_no_bak
    set -l file $argv[1]
    if test -z "$file"
        awk '{ if (line[$0] != 42) { print $0 }; line[$0] = 42; }'
    else
        _dedup_file $file no
    end
end

function drop_caches
    echo 3 | sudo tee /proc/sys/vm/drop_caches
end

function ssl_connect
    set -l address $argv[1]
    openssl s_client -connect $address
end

function ssl_dates
    ssl_connect $argv | openssl x509 -noout -dates
end

function lastu
    last | grep -E -v '(root|cron|nagios)'
end

function lastl
    lastu | less
end

abbr wetter 'curl http://wttr.in'

abbr tf terraform
abbr tfplan 'terraform plan -out=tfplan'
abbr tfappl 'terraform apply tfplan'

function touchtype
    tt --noskip --noreport --showwpm --bold --theme (tt -list themes | sort -R | head -n1) $argv
end

function touchtype::quote
    while true
        touchtype -quotes en
        sleep 0.2
    end
end

function touchtype::scifi
    find ~/git/scifi/summaries/ -type f -name \*.md | sort -R | head -n 1 | xargs cat | touchtype
end

function checkcert
    set host $argv[1]
    set port $argv[2]
    openssl s_client \
        -connect $host:$port \
        -servername $host \
        -showcerts </dev/null 2>/dev/null | openssl x509 -noout -dates -subject
end

abbr typing 'touchtype::quote'

function sway_config_view
    less /etc/sway/config
end

function ssh::force
    set -l server $argv[1]
    ssh-keygen -R $server
    ssh -A $server
end

function geheim
    echo 'Use KeePassXC and/or foostore'
end

function snonux::sync
    # snonux microblogger tool
    ~/go/bin/snonux --input ~/.gosdir/snonux/inbox/ --output ~/.gosdir/snonux/dist/ --sync
end
