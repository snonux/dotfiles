if [ -e ~/Notes ]; then
    notes::wisdom () {
        $VISUAL ~/Notes/*/Wisdoms.md
    }

    notes::habit () {
        $VISUAL ~/Notes/*/Habits.md
    }

    notes::edit () {
        cd ~/Notes
        $VISUAL "$(find . -type f | fzf)"
        cd -
    }

    alias ,ne=notes::edit
fi
