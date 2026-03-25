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

function tmux::project
    if test (count $argv) -eq 0
        set -l git_root (basename (git rev-parse --show-toplevel 2>/dev/null))
        if test -n "$git_root"
            tmux::attach (basename $git_root)
            return
        end
        echo "tp: no argument given and not in a git repo"
        return 1
    end

    set -l dir (zoxide query -i $argv[1] 2>/dev/null)
    if test $status -ne 0; or test -z "$dir"
        echo "tp: no zoxide match for '$argv[1]'"
        return 1
    end

    cd $dir
    tmux::attach (basename $dir)
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
alias tp 'tmux::project'
alias notes 'cd ~/Notes; tmux::attach notes'
alias N 'cd ~/Notes; tmux::attach notes'
alias bar 'tmux::new bar'
alias baz 'tmux::new baz'
alias bay 'tmux::new bay'
abbr -a tkt "tmux list-sessions -F '#{session_name}' | grep -- '-tmp-' | xargs -I{} tmux kill-session -t '{}'"
