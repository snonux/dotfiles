lsof::listening () {
    local pid=$1
    sudo lsof -p $pid -a -i -sTCP:LISTEN -P
}
