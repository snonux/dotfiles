if [ -f ~/.config/rakuandperlenabled ]; then
    export RAKUBREW_HOME=~/rakubrew
    export PATH=$(rakubrew home)/shims:$PATH
fi
