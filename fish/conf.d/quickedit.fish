set -gx QUICKEDIT_DIR ~/QuickEdit

# Suffixes treated as binary: omitted from the quickedit index and picker (add as needed).
set -g quickedit_ignore_suffixes \
    .pdf .png .jpg .jpeg .gif .webp .bmp .ico .tiff .tif \
    .zip .tar .gz .tgz .bz2 .xz .7z .rar .zst \
    .mp3 .mp4 .mkv .avi .wav .flac .webm .mov \
    .bin .exe .dll .so .dylib .o .a \
    .woff .woff2 .ttf .eot .otf \
    .sqlite .db \
    .doc .docx .ppt .pptx .xls .xlsx \
    .odt .ods .odg .odp .sxw \
    .apkg .apk .kdbx .pfx .p12 \
    .epub .mht .mhtml .gnumeric .abw \
    .blend .sh3d \
    .spd .spd-wal .spd-shm \
    .note

function quickedit::filter_ignore_suffixes
    set -l out
    for f in $argv
        set -l skip 0
        for suffix in $quickedit_ignore_suffixes
            if string match -qi "*$suffix" $f
                set skip 1
                break
            end
        end
        if test $skip -eq 0
            set out $out $f
        end
    end
    printf '%s\n' $out
end

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

function quickedit::run
    set -l run_postaction $argv[1]
    set -l prev_dir (pwd)
    set -l grep_pattern .

    if test (count $argv) -gt 1
        set grep_pattern $argv[2]
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
        set -l find_args -L . -type f -not -path '*/.*'
        if test (count $quickedit_ignore_suffixes) -gt 0
            set find_args $find_args '('
            for suffix in $quickedit_ignore_suffixes
                set find_args $find_args ! -name "*$suffix"
            end
            set find_args $find_args ')'
        end
        find $find_args | sort >$QUICKEDIT_DIR/.index.tmp && mv $QUICKEDIT_DIR/.index.tmp $QUICKEDIT_DIR/.index
    end

    set files (quickedit::filter_ignore_suffixes (grep -E "$grep_pattern" $QUICKEDIT_DIR/.index))
    switch (count $files)
        case 0
            echo No result found
            cd $prev_dir
            return
        case 1
            set file_path $files[1]
        case '*'
            set file_path (printf '%s\n' $files REINDEX ABORT | fzf)
    end

    if test "$file_path" = ABORT; or test -z "$file_path"
        cd $prev_dir
        return
    end

    if test "$file_path" = REINDEX
        rm -f $QUICKEDIT_DIR/.index
        cd $prev_dir
        quickedit::run $run_postaction $argv[2..-1]
        return
    end

    if editor::helix::open_with_lock $file_path
        if test "$run_postaction" = 1
            quickedit::postaction $file_path
        end
    end

    cd $prev_dir
end

function quickedit
    quickedit::run 1 $argv
end

function quickview
    quickedit::run 0 $argv
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
