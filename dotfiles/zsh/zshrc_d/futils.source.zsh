viewcmd () {
    local -r cmd=$1
    view $(where $cmd | head -n 1)
}
