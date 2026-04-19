set -l foostore_bin ~/go/bin/foostore

if test -x $foostore_bin
    $foostore_bin fish | source
else
    echo No $foostore_bin found
end
