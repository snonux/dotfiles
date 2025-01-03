export UPRECORDS_DIR=~/git/uprecords
export UPRECORDS_REPO=git@codeberg.org:snonux/uprecords.git

uprecords::os () {
    if [ $(uname) = FreeBSD ]; then
        echo -n 'FreeBSD '
        freebsd-version
    elif [ $(uname) = OpenBSD ]; then
        echo -n 'OpenBSD '
        uname -r
    elif [ $(uname) = Darwin ]; then
        echo -n 'Darwin '
        uname -r
    elif [ -f /etc/debian_version ]; then
        cat /etc/debian_version
    else
        cat $(ls -d /etc/*release* | head -n 1)
    fi
}

uprecords::collect () {
    readonly hostname=$(hostname | cut -d. -f1 | sed 's/..-lon-mb/mega/; s/MBDVXJ4XKH9C/mega-m3-pro/;')

    if [ $(whoami) = root ]; then
        return 1
    fi

    if [ ! -d $UPRECORDS_DIR ]; then
        git clone $UPRECORDS_REPO $UPRECORDS_DIR
        cd $UPRECORDS_DIR
    else
        cd $UPRECORDS_DIR
        git pull
    fi

    if [ -f /var/spool/uptimed/records ]; then
        # Debian, Ubuntu and FreeBSD
        records_path=/var/spool/uptimed/records
    elif [ -f /var/db/uptimed/records ]; then
        # OpenBSD
        records_path=/var/db/uptimed/records
    else
        # Homebrew (MacOS)
	      records_path=/opt/homebrew/var/uptimed/records
    fi

    cp $records_path ./stats/$hostname.records
    uprecords -a -m 100 > ./stats/$hostname.txt
    uprecords -a | grep '^->' > ./stats/$hostname.cur.txt
    which guprecords &>/dev/null && make

    local -r os=$(uprecords::os)
    touch ./stats/$hostname.os.txt
    grep -q "$os" ./stats/$hostname.os.txt
    if [ $? -ne 0 ]; then
        echo "$os" >> ./stats/$hostname.os.txt
    fi
    if [ -e /proc/cpuinfo ]; then
        cat /proc/cpuinfo > ./stats/$hostname.cpuinfo.txt
    elif [ $(uname) = Darwin ]; then
        sysctl -a | grep machdep.cpu >./stats/$hostname.cpuinfo.txt
    fi

    git add ./stats/$hostname.*
    git add ./*.txt
    git commit -m "New uprecords for host $hostname"
    git push 

    cd -
}

uprecords::sync () {
    grep -q running ~/.config/snonux/etc/uptimed_ensure && uprecords::collect
}
