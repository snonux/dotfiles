declare NOTES_DIR=$HOME/Notes

if [ -e $NOTES_DIR ]; then
    notes::edit () {
        cd ~/Notes
        $VISUAL "$(find . -type f | fzf)"
        cd -
    }

    alias ,ne=notes::edit
    alias cdnodes="cd $NOTES_DIR"
fi
