set -l foostore_bin ~/go/bin/foostore

if test -x $foostore_bin
    $foostore_bin fish | source
end
