export GOS_BIN=~/go/bin/gos
export GOS_DIR=~/.gosdir

if [ -f $GOS_BIN ]; then
  alias cdgos="cd $GOS_DIR"
fi
