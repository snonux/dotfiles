export GOS_BIN=~/go/bin/gos

if [ -f $GOS_BIN ]; then
  alias gosc="$GOS_BIN --compose"
  alias cdgos="cd $GOS_DIR"
fi
