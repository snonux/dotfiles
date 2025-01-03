export GOS_DIR=~/Notes/GosDir

gos::compose () {
    local -r compose_file=$GOS_DIR/$(date +%s).txt
    $EDITOR $compose_file.tmp && mv $compose_file.tmp $compose_file
}
alias gosc=gos::compose

gos::run () {
    if [ ! -f ~/go/bin/gos ]; then
        echo "gos not installed?"
        return
    fi
    ~/go/bin/gos -gosDir $GOS_DIR
}
alias gosr=gos::run
alias cdgos="cd $GOS_DIR"
