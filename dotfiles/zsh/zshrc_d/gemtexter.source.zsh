declare GEMTEXTER_DIR=$HOME/git/gemtexter
declare GEMTEXTER_FOO_DIR=$HOME/git/foo.zone-content/gemtext

if [ -d $GEMTEXTER_DIR ]; then
    gemtexter::edit () {
        local -r dir="$1"; shift
        cd $dir
        $VISUAL "$(find . -type f -not -path '*/.git/*' | fzf)"
        git::quickpush
        cd -
    }

    gemtexter::publish () {
        local -r config_file="$1"; shift
        cd "$GEMTEXTER_DIR"
        CONFIG_FILE_PATH="$config_file" ./gemtexter --publish
        cd -
    }

    gemtexter::foo::edit () {
        gemtexter::edit "$GEMTEXTER_FOO_DIR"
    }
    alias .gfe=gemtexter::foo::edit
    alias .gfp=gemtexter::publish "$GEMTEXTER_DIR/gemtexter.conf"
fi
