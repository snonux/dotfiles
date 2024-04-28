declare GEMTEXTER_DIR=$HOME/git/gemtexter
declare GEMTEXTER_FOO_DIR=$HOME/git/foo.zone-content/gemtext
declare GEMTEXTER_PAUL_DIR=$HOME/git/paul.buetow.org-content/gemtext

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

    gemtexter::paul::edit () {
        gemtexter::edit "$GEMTEXTER_PAUL_DIR"
    }
    alias .gpe=gemtexter::paul::edit
    alias .gpp="gemtexter::publish '$GEMTEXTER_DIR/gemtexter-paul.buetow.org.conf'"
fi
