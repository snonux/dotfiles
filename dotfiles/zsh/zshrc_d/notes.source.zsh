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
        $EDITOR "$file"
    }
    alias ,nq=notes::quick

    notes::quick::find () {
        local -r name="$1"; shift
        local -r note="$(find $NOTES_DIR/ -iname "*$name*.md" | head -n 1)"

        if [ ! -f "$note" ]; then
            echo "Could not find any note in $NOTES_DIR"
            return
        fi

        $EDITOR $note
    }
    alias ,nf=notes::quick::find
fi
