set -g EDITOR hx
fish_vi_key_bindings

# Use $EDITOR to edit the current command
function edit-command
    set -q EDITOR; or return 1
    set -l tmpfile (mktemp --suffix .fish); or return 1
    commandline >$tmpfile
    eval $EDITOR $tmpfile
    commandline -r -- (cat $tmpfile)
    rm $tmpfile
end
