if [ -e ~/Notes ]; then
    notes::wisdom () {
        $VISUAL ~/Notes/*/Wisdoms.md
    }

    notes::habit () {
        $VISUAL ~/Notes/*/Habits.md
    }
fi
