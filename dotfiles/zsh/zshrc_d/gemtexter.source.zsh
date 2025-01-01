export GEMTEXTER_DIR=$HOME/git/gemtexter
export GEMTEXTER_FOO_DIR=$HOME/git/foo.zone-content/gemtext

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

    gemtexter::publish::file () {
        local -r file="$1"; shift

        cd "$GEMTEXTER_DIR"
        ./gemtexter --generate "$file"
        ./gemtexter --git
        ./post_publish_hook.sh
        cd -
    }

    gemtexter::foo::edit () {
        gemtexter::edit "$GEMTEXTER_FOO_DIR"
    }
    alias .gfe=gemtexter::foo::edit
    alias .gfp=gemtexter::publish "$GEMTEXTER_DIR/gemtexter.conf"
    alias .gff=gemtexter::publish::file 

    gemtexter::random::note () {
        amfora $(find ~/git/foo.zone-content/gemtext/notes -name \*.gmi | sort -R | head -n 1 | sed 's|.*foo.zone-content/gemtext|gemini://foo.zone/|')
    }
    alias .grn=gemtexter::random::note
fi
