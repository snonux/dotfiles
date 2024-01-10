declare NOTES_DIR=$HOME/Notes

if [ -e $NOTES_DIR ]; then
    notes::edit () {
        cd ~/Notes
        $VISUAL "$(find . -type f | fzf)"
        cd -
    }

    alias ,ne=notes::edit
    alias cdnodes="cd $NOTES_DIR"

    notes::quick () {
        local -r name="$1"; shift
        local -r file="$NOTES_DIR/$name.md"
        if [ ! -f "$file" ]; then
            echo "# $name" >> "$file"
        fi
        nvim "$file"
    }
    alias ,nq=notes::quick
fi
