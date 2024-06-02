alias tm=tmux
alias tl='tmux list-sessions'

tmux::cleanup_default () {
    local s
    tmux list-sessions | grep '^T.*: ' | grep -F -v attached |
    cut -d: -f1 | while read -r s; do
        echo "Killing $s"
        tmux kill-session -t "$s"
    done
}

# Create new session and if alread exists attach to it
tmux::new () {
    readonly session=$1
    local date=date
    if where gdate &>/dev/null; then
        date=gdate
    fi

    tmux::cleanup_default
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

# Create new session and directly SSH into the given server
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

# SSH into multiple servers, one tmux pane per server.
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
    local first_server=$1; shift

    if [ -z "$first_server" ]; then
        first_server=$session
    fi

    tmux new-session -d -s $session "ssh -t $first_server"
    if ! tmux list-session | grep "^$session:"; then
        echo "Could not create session $session"
        return 2
    fi

    for server in "${@[@]}"; do
        tmux split-window -t $session "tmux select-layout tiled; ssh -t $server"
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
