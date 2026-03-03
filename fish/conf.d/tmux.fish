set -gx TMUX_FZF_GIT_INDEX ~/git/.index

function _tmux::cleanup_default
    tmux list-sessions | string match -r '^T.*: ' | string match -v -r attached | string split ':' | while read -l s
        echo "Killing $s"
        tmux kill-session -t "$s"
    end
end

function _tmux::connect_command
    set -l server_or_pod $argv[1]
    if test -z "$TMUX_KEXEC"
        echo "ssh -A -t $server_or_pod"
    else
        echo "kubectl exec -it $server_or_pod -- /bin/bash"
    end
end

function tmux::new
    set -l session $argv[1]
    _tmux::cleanup_default
    if test -z "$session"
        tmux::new (string join "" T (date +%s))
    else
        tmux new-session -d -s $session
        tmux -2 attach-session -t $session || tmux -2 switch-client -t $session
    end
end

function tmux::git_project
    set -l filter (test -n "$argv[1]"; and echo $argv[1]; or echo .)
    set -l git_dir ~/git

    set -l index_age 0
    if test -f $TMUX_FZF_GIT_INDEX
        if test (uname) = Darwin
            set $TMUX_FZF_GIT_INDEX_age (math (date +%s) - (stat -f %m $TMUX_FZF_GIT_INDEX))
        else
            set $TMUX_FZF_GIT_INDEX_age (math (date +%s) - (stat -c %Y $TMUX_FZF_GIT_INDEX))
        end
    end
    if test $index_age -gt 86400
        rm $TMUX_FZF_GIT_INDEX
    end

    if not test -f $TMUX_FZF_GIT_INDEX
        find $git_dir -maxdepth 4 -type d -name .git \
            | sed 's|/.git$||' | sed "s|$git_dir/||" \
            | grep -F -v . | grep -v gitsyncer-workdir >$TMUX_FZF_GIT_INDEX
    end

    set -l matches (grep "$filter" $TMUX_FZF_GIT_INDEX)
    set -l session
    if test (count $matches) -eq 1
        set session $matches[1]
    else
        set session (printf "%s\n" $matches | fzf)
    end
    cd $git_dir/$session
    tmux::attach $session
end

function tmux::git_project::reindex
    if test -f $TMUX_FZF_GIT_INDEX
        rm $TMUX_FZF_GIT_INDEX
    end
    tmux::git_project $argv
end

function tmux::attach
    set -l session $argv[1]
    if test -z "$session"
        tmux attach-session || tmux::new
    else
        tmux attach-session -t $session || tmux::new $session
    end
end

function tmux::remote
    set -l server $argv[1]
    tmux new -s $server "ssh -A -t $server 'tmux attach-session || tmux'" || tmux attach-session -d -t $server
end

function tmux::search
    set -l session (tmux list-sessions | fzf | cut -d: -f1)
    if test -z "$TMUX"
        tmux attach-session -t $session
    else
        tmux switch -t $session
    end
end

function tmux::cluster_ssh
    if test -f "$argv[1]"
        tmux::tssh_from_file $argv[1]
        return
    end
    tmux::tssh_from_argument $argv
end

function tmux::tssh_from_argument
    set -l session $argv[1]
    set first_server_or_container $argv[2]
    set remaining_servers $argv[3..-1]
    if test -z "$first_server_or_container"
        set first_server_or_container $session
    end

    tmux new-session -d -s $session (_tmux::connect_command "$first_server_or_container")
    if not tmux list-session | grep "^$session:"
        echo "Could not create session $session"
        return 2
    end
    for server_or_container in $remaining_servers
        tmux split-window -t $session "tmux select-layout tiled; $(_tmux::connect_command "$server_or_container")"
    end
    tmux setw -t $session synchronize-panes on
    tmux -2 attach-session -t $session || tmux -2 switch-client -t $session
end

function tmux::tssh_from_file
    set -l serverlist $argv[1]
    set -l session (basename $serverlist | cut -d. -f1)
    tmux::tssh_from_argument $session (awk '{ print $1 }' $serverlist | sed 's/.lan./.lan/g')
end

alias tn 'tmux::new'
alias ta 'tmux::attach'
alias tx 'tmux::remote'
alias tl 'tmux::search'
alias tssh 'tmux::cluster_ssh'
alias tp 'tmux::git_project'
alias foo 'tmux::new foo'
alias bar 'tmux::new bar'
alias baz 'tmux::new baz'
alias bay 'tmux::new bay'
