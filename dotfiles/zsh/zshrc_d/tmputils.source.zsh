TMPUTILS_DIR=~/data/tmp
TMPUTILS_TMPFILE=~/.tmpfile

tmpls () {
    if [ ! -d $TMPUTILS_DIR ]; then
        return
    fi

    ls $TMPUTILS_DIR
}
alias Ls=tmpls

alias cdtmp="cd $TMPUTILS_DIR"

tmptee () {
    local name=$1

    if [ -z $name ]; then
        name=$(date +%Y%m%d-%H:%M:%S)
    else
        shift
    fi
    local -r file=$TMPUTILS_DIR/$name

    if [ ! -d $TMPUTILS_DIR ]; then
        mkdir -p $TMPUTILS_DIR
    fi

    tee $@ $file
    echo $file > $TMPUTILS_TMPFILE
}
alias Tee=tmptee

tmpcat () {
    local -r name=$1

    if [ -z $name ]; then
        cat $(tmpfile)
        return
    fi

    cat $TMPUTILS_DIR/$name
}
alias Cat=tmpcat

tmpedit () {
    local -r name=$1

    if [ -z $name ]; then
        $EDITOR $(tmpfile)
        return
    fi

    $EDITOR $TMPUTILS_DIR/$name
}
alias Edit=tmpedit

tmpgrep () {
    local -r name=$1 ; shift
    tmcpat $name | grep "$@"
}
alias Grep=tmpgrep

tmpfile () {
    cat $TMPUTILS_TMPFILE
}
