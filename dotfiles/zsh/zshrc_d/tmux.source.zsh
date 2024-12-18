alias tm=tmux
alias tl='tmux list-sessions'

tmux::_cleanup_default () {
    local s
    tmux list-sessions | grep '^T.*: ' | grep -F -v attached |
    cut -d: -f1 | while read -r s; do
        echo "Killing $s"
        tmux kill-session -t "$s"
    done
}

tmux::_connect_command () {
    local -r server_or_pod="$1"; shift

    if [ -z "TMUX_KEXEC" ]; then
        echo "ssh -t $server_or_pod"
    else
        echo "kubectl exec -it $server_or_pod -- /bin/bash"
    fi
}


# Create new session and if alread exists attach to it
tmux::new () {
    readonly session=$1
    local date=date
    if where gdate &>/dev/null; then
        date=gdate
    fi

    tmux::_cleanup_default
    if [ -z "$session" ]; then
        tmux::new T$($date +%s)
    else
        tmux new-session -d -s $session
        tmux -2 attach-session -t $session || tmux -2 switch-client -t $session
    fi
}
alias tn=tmux::new

tmux::attach () {
    readonly session=$1

    if [ -z "$session" ]; then
        tmux attach-session || tmux::new
    else
        tmux attach-session -t $session || tmux::new $session
    fi
}
alias ta=tmux::attach

# Create new session andthe given server or container
tmux::remote () {
    readonly server=$1
    tmux new -s $server "ssh -t $server 'tmux attach-session || tmux'" || tmux attach-session -d -t $server
}
alias tx=tmux::remote

# Fuzzy search tmux session and attach or switch to it.
tmux::search () {
    local -r session=$(tmux list-sessions | fzf | cut -d: -f1)
    if [ -z "$TMUX" ]; then
        tmux attach-session -t $session
    else
        tmux switch -t $session
    fi
}
alias ts=tmux::search

# Connect to multiple servers or containers, one tmux pane per target.
tmux::cluster_ssh () {
    if [ -f "$1" ]; then
        tmux::tssh_from_file $1
        return
    fi

    tmux::tssh_from_argument $@
}
alias tssh=tmux::cluster_ssh

# Create a new tmux session with many servers in it
tmux::tssh_from_argument () {
    local -r session=$1; shift
    local first_server_or_container=$1; shift

    if [ -z "$first_server_or_container" ]; then
        first_server_or_container=$session
    fi

    tmux new-session -d -s $session "$(tmux::_connect_command "$first_server_or_container")"
    if ! tmux list-session | grep "^$session:"; then
        echo "Could not create session $session"
        return 2
    fi

    for server_or_container in "${@[@]}"; do
        tmux split-window -t $session "tmux select-layout tiled; $(tmux::_connect_command "$server_or_container")"
    done

    tmux setw -t $session synchronize-panes on
    tmux -2 attach-session -t $session | tmux -2 switch-client -t $session
}

# Same as tssh, but based on a server list from a file
tmux::tssh_from_file () {
    local -r serverlist=$1; shift
    local -r session=$(basename $serverlist | cut -d. -f1)

    tmux::tssh_from_argument $session $(awk '{ print $1} ' $serverlist | sed 's/.lan./.lan/g')
}

alias foo='tmux::new foo'
alias bar='tmux::new bar'
