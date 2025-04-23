set -gx QUICKEDIT_DIR ~/QuickEdit

function quickedit
    set -l prev_dir (pwd)
    set -l grep_pattern .

    if test (count $argv) -gt 0
        set grep_pattern $argv[1]
    end

    cd $QUICKEDIT_DIR
    set -l file_path (find -L . -type f -not -path '*/.*' | grep "$grep_pattern" | fzf)
    $EDITOR $file_path

    # Go to git toplevel dir (if exists)
    cd (dirname $file_path)
    set -l git_dir (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -eq 0
        cd $git_dir
    end
    if test -f Makefile
        make
    end
    if test -d .git
        git commit -a -m Update
        git pull
        git push
    end

    cd $prev_dir
end


abbr -a cdquickedit "cd $QUICKEDIT_DIR"
abbr -a ,qe quickedit
abbr -a ,ne quickedit
abbr -a ,qr "ranger $QUICKEDIT_DIR"
