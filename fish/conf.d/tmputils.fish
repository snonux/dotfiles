set -gx TMPUTILS_DIR ~/data/tmp
set -gx TMPUTILS_TMPFILE ~/.tmpfile

function tmpdir
    set -l name $argv[1]
    set -l dir "$TMPUTILS_DIR/$name"
    if not test -d $dir
        mkdir -p $dir
    end
    cd $dir
end

function tmpnew
    set -l name $argv[1]
    tmpdir $argv
    tmux::attach $name
end

function tmpls
    if not test -d $TMPUTILS_DIR
        return
    end
    ls $TMPUTILS_DIR
end

function tmptee
    set -l name $argv[1]
    if test -z "$name"
        set name (date +%s)
    else
        set -e argv[1]
    end
    set -l file "$TMPUTILS_DIR/$name"
    if not test -d $TMPUTILS_DIR
        mkdir -p $TMPUTILS_DIR
    end
    tee $argv $file
    echo $file >$TMPUTILS_TMPFILE
end

function tmpcat
    set -l name $argv[1]
    if test -z "$name"
        cat (tmpfile)
        return
    end
    cat "$TMPUTILS_DIR/$name"
end

function tmpedit
    set -l name $argv[1]
    if test -z "$name"
        $EDITOR (tmpfile)
        return
    end
    $EDITOR "$TMPUTILS_DIR/$name"
end

function tmpgrep
    set -l name $argv[1]
    set -e argv[1]
    tmcpat $name | grep $argv
end

function tmpfile
    cat $TMPUTILS_TMPFILE
end

function tmpmove
    set -l name (basename (pwd))
    set -l src (pwd)
    set -l dest ~/Notes/tmp/$name

    if test "$src" != "$TMPUTILS_DIR/$name"
        echo "tmpmove: not inside a tmp directory ($TMPUTILS_DIR/<name>)"
        return 1
    end

    mkdir -p ~/Notes/tmp
    mv $src $dest
    cd $dest
    echo "Moved $src -> $dest"
end

function __tmpclean_stat_mtime --argument file
    # Portable file mtime in seconds since epoch (Linux vs macOS)
    if test (uname) = Darwin
        stat -f %m "$file" 2>/dev/null
    else
        stat -c %Y "$file" 2>/dev/null
    end
end

function tmpclean
    if not test -d "$TMPUTILS_DIR"
        echo "tmpclean: TMPUTILS_DIR ($TMPUTILS_DIR) does not exist"
        return 1
    end

    set -l old_dir "$TMPUTILS_DIR/OLD"
    mkdir -p $old_dir

    set -l datestamp (date +%Y%m%d)
    set -l threshold 31
    set -l now (date +%s)

    for folder in $TMPUTILS_DIR/*
        # Skip the OLD directory itself and non-directories
        test "$folder" = "$old_dir"; and continue
        test -d "$folder"; or continue

        # Find the most recently modified file inside the folder (including subdirs)
        set -l newest
        if test (uname) = Darwin
            set newest (find "$folder" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1)
        else
            set newest (find "$folder" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
        end

        # Determine mtime: newest file, or folder mtime if empty
        set -l mtime
        if test -n "$newest"
            set mtime (math floor "$newest")
        else
            set mtime (__tmpclean_stat_mtime "$folder")
        end

        # Skip if we couldn't determine mtime
        if test -z "$mtime"
            echo "tmpclean: skipping $folder (could not read mtime)"
            continue
        end

        set -l age_days (math \( $now - $mtime \) / 86400)

        if test -n "$age_days"; and test "$age_days" -ge $threshold
            set -l basename (basename "$folder")
            set -l dest "$old_dir/$basename.$datestamp"
            echo "Moving $folder -> $dest (stale $age_days days)"
            mv "$folder" "$dest"
        end
    end
end

abbr -a cdtmp "cd $TMPUTILS_DIR"
abbr -a tmpn tmpnew
abbr -a temp tmpnew
abbr -a tmp tmpnew