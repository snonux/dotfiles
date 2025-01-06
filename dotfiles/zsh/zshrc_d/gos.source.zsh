export GOS_BIN=~/go/bin/gos
export GOS_DIR=~/.gosdir

if [ -f $GOS_BIN ]; then
  alias gosc="$GOS_BIN --compose"
  alias cdgos="cd $GOS_DIR"
fi
