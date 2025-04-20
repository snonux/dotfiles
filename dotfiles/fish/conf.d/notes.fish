set NOTES_DIR ~/Notes

function notes::edit
    cd ~/Notes
    $VISUAL (find . -type f | fzf)
    cd - >/dev/null
end

function notes::quick
    set -l name $argv[1]
    set -l file "$NOTES_DIR/$name.md"
    if not test -f "$file"
        echo "# $name" >>"$file"
    end
    $EDITOR "$file"
end

function notes::quick::find
    set -l name $argv[1]
    set -l note (find $NOTES_DIR/ -iregex ".*$name.*\.\(md\|txt\)" | head -n 1)
    if not test -f "$note"
        echo "Could not find any note in $NOTES_DIR"
        return
    end
    $EDITOR "$note"
end

abbr -a ,ne 'notes::edit'
abbr -a cdnodes "cd $NOTES_DIR"
abbr -a ,nq 'notes::quick'
abbr -a ,nf 'notes::quick::find'
abbr -a ,nr "ranger $NOTES_DIR"
