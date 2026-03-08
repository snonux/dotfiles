set -gx QUICKEDIT_DIR ~/QuickEdit

function quickedit::postaction
    set -l file_path $argv[1]
    set -l make_run 0

    if test -f Makefile
        make
        set make_run 1
    end

    # Go to git toplevel dir (if exists)
    cd (dirname $file_path)
    set -l git_dir (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -eq 0
        cd $git_dir
    end
    if not test $make_run -eq 1
        if test -f Makefile
            make
        else if test -f Justfile
            just
        end
    end
    if test -d .git
        git commit -a -m Update
        git pull
        git push
    end
end

function quickedit
    set -l prev_dir (pwd)
    set -l grep_pattern .

    if test (count $argv) -gt 0
        set grep_pattern $argv[1]
    end

    cd $QUICKEDIT_DIR
    set -l index_age 99999
    if test -f .index
        if test (uname) = Darwin
            set index_age (math (date +%s) - (stat -f %m .index))
        else
            set index_age (math (date +%s) - (stat -c %Y .index))
        end
    end
    if test $index_age -gt 86400
        echo Indexing quickedit
        find -L . -type f -not -path '*/.*' | sort >$QUICKEDIT_DIR/.index.tmp && mv $QUICKEDIT_DIR/.index.tmp $QUICKEDIT_DIR/.index
    end

    set files (grep -E "$grep_pattern" $QUICKEDIT_DIR/.index)
    switch (count $files)
        case 0
            echo No result found
            return
        case 1
            set file_path $files[1]
        case '*'
            set file_path (printf '%s\n' $files | fzf)
    end

    if editor::helix::open_with_lock $file_path
        quickedit::postaction $file_path
    end

    cd $prev_dir
end

function slowedit
    if test -f $QUICKEDIT_DIR/.index
        rm $QUICKEDIT_DIR/.index
    end
    quickedit $argv
end

abbr -e E slowedit
abbr -a e quickedit
abbr -a er "ranger $QUICKEDIT_DIR"
abbr -a cdquickedit "cd $QUICKEDIT_DIR"
abbr -a cdnotes 'cd ~/Notes'
abbr -a cdfish 'cd ~/.config/fish/conf.d'
abbr -a cddocs 'cd ~/Documents'
abbr -a cdocs 'cd ~/Documents'
abbr may 'hx ~/Notes/random/Maybe.md'
