set -x GOS_BIN ~/go/bin/gos
set -x GOS_DIR ~/.gosdir

if test -f $GOS_BIN
    alias cdgos "cd $GOS_DIR"
end
