motd () {
    cat /etc/motd
}

fullest_h () {
    df -h | sort -n -k 5
}

fullest_i () {
    df -i | sort -n -k 5
}

lshelpers () {
    local -r what=$1
    fgrep --color=auto ' () {' ~/.zshrc_*/$what.source.zsh | sed 's/ {//'
}

usortn () {
    sort | uniq -c | sort -n
}

gdbrun () {
    gdb -ex=run --args $@
}

asum () {
    awk '{ sum += $1 } END { print sum }'
}

hral () {
    # Human readable audit logs
    awk '{ time=gensub(/.*audit.(.*)\..*/, "\\1", "g", $2); $2 = ""; printf "%s -> %s\n", strftime("%m%d-%H%M%S", time), $0; }'
}

compact_memory () {
    sudo bash -c 'echo 1 > /proc/sys/vm/compact_memory'
}

svgoto () {
    local -r file=$1
    local -r goto=$2
    sudo vim -c "goto $goto" $file
}

vgoto () {
    local -r file=$1
    local -r goto=$2
    vim -c "goto $goto" $file
}

pof () {
    local -r pattern=$1
    sudo lsof -p $(pgrep -f $pattern)
}

if [ $UNAME = Linux ]; then
    plimits() {
        local -r pattern=$1
        sudo cat /proc/$(pgrep -f $pattern)/limits
    }

    ptop() {
        local -r pattern=$1
        sudo top -p $(sudo pgrep -f $pattern)
    }

    swappy() {
        local count=$1
        s dd if=/dev/zero of=/swapfile$count bs=1024 count=$((1024 * 1024 * 4))
        s mkswap /swapfile$count
        s swapon /swapfile$count
        echo You have to add this to fstab:
        echo /swapfile$count swap swap defaults 0 0
    }

    extfs_ratio() {
        readonly device=$1

        if [ -z $device ]; then
            df | sed /Filesystem/d | cut -d' ' -f1 |
            while read dev; do
                ext_ratio $dev
            done
        else
            echo -n "$device: "
            sudo tune2fs -l $device |
            awk -F: ' \
                /^Block count:/ { blocks = $2 } \
                /^Inode count:/ { inodes = $2 } \
                /^Block size:/ { block_size = $2 } \
                END { blocks_per_inode = blocks/inodes; \
                print " blocks per inode:", blocks_per_inode, \
                " bytes per inode:", blocks_per_inode * block_size }'
        fi
    }

    2dos() {
        sed 's/$'"/`echo \\\r`/" $@
    }

    2dos_i() {
        sed -i 's/$'"/`echo \\\r`/" $@
    }
fi # If Linux

2unix() {
    perl -pe 's/\r\n|\n|\r/\n/g'
}

maint_banner () {
  cat <<END

██████╗ ██████╗ ██╗   ██╗███████╗████████╗ ██████╗ ██╗    ██╗
██╔══██╗██╔══██╗██║   ██║██╔════╝╚══██╔══╝██╔═══██╗██║    ██║
██████╔╝██████╔╝██║   ██║█████╗     ██║   ██║   ██║██║ █╗ ██║
██╔═══╝ ██╔══██╗██║   ██║██╔══╝     ██║   ██║   ██║██║███╗██║
██║     ██████╔╝╚██████╔╝███████╗   ██║   ╚██████╔╝╚███╔███╔╝
╚═╝     ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝    ╚═════╝  ╚══╝╚══╝

██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗
██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝
██║ █╗ ██║██║   ██║██████╔╝█████╔╝ ██║██╔██╗ ██║██║  ███╗
██║███╗██║██║   ██║██╔══██╗██╔═██╗ ██║██║╚██╗██║██║   ██║
╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝
 ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝

██╗  ██╗███████╗██████╗ ███████╗
██║  ██║██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██████╔╝█████╗
██╔══██║██╔══╝  ██╔══██╗██╔══╝
██║  ██║███████╗██║  ██║███████╗██╗██╗██╗
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝╚═╝

END
}

maint() {
    readonly arg=$1
    all="$@"
    readonly maintfile=/root/.maint
    echo "Checking whether Puppet is running"
    pgrep -lf puppet 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Puppet is still running, terminating it"
        sudo pkill -f puppet
        sleep 1
    fi 

    if [ -z $arg ]; then
        echo -n 'Maintenance mode is currently '
        sudo test -f $maintfile && echo on || echo off
        sudo test -f $maintfile && echo -n /root/.maint: && sudo cat /root/.maint
        echo -n '/etc/motd:'; tail -n 1 /etc/motd

    elif [ $arg = off ]; then
        echo Toggling maintenance mode to off
        sudo rm $maintfile 2>/dev/null

    else
        local message="$(date +%Y%m%d) $USER: $all"

        echo Toggling maintenance mode to on
        maint_banner | sudo tee -a /etc/motd >/dev/null
        sudo tee -a /etc/motd <<< "$message"
        sudo tee -a $maintfile <<< "$message" 2>/dev/null
    fi
}

maint_until() {
    local -r at=$1 ; shift
    maint $@ " (Leaving maintenance mode at $at via atd)"
    unmaint_at $at
}

m11() {
    maint $@
    unmaint_at 11pm
}

unmaint() {
    maint off
}

unmaint_at() {
    readonly at=$1
    readonly maintfile=/root/.maint

    sudo at $at <<< "/bin/rm $maintfile"
}

### LOG TAIL HELPERS ###

lt() {
    readonly today=$(date +'%Y%m%d')
    local cmd=$1
    local params

    if [ -z $cmd ]; then
        cmd=tail
        params=-f
    else
        shift
        params=$@
    fi

    # Run the F command inside of less to autotail
    if [ -f $today.log ]; then
        $cmd $params $today.log

    elif [ -f $today ]; then
        $cmd $params $today

    elif [ -f log/$today.log ]; then
        $cmd $params log/$today.log

    elif [ -f log/$today ]; then
        $cmd $params log/$today

    else
        echo 'No logfile to tail'
        return -1
    fi
}

le() {
    lt $@ | fgrep ERROR
}

ltt() {
    tail -n 100000 $(today).log
}

### SERVICE HELPERS ###

stop() {
    readonly service=$1 ; shift
    sudo service $service stop $@
}

start() {
    readonly service=$1 ; shift
    sudo service $service start $@
}

restart() {
    readonly service=$1 ; shift
    sudo service $service restart $@
}

status() {
    readonly service=$1 ; shift
    sudo service $service status $@
}

### SUDO HELPERS ###

ask_sudo() {
    echo -n "Want to run $@? (y/n) "
    read yn
    case $yn in
        y*) sudo $@;;
        *) echo Not doing it;;
    esac
}

### CD HELPERS

# cd into newest directory
cdn() {
    readonly pattern="${1}" ; shift
    readonly dir=$(ls -tF | grep "$pattern.*/\$" | head -n 1)

    if [ -d "$dir" ]; then
        cd "$dir"
    else
        echo "No such dir $dir"
    fi
}

# cd into parallel directory
cdpal() {
    readonly from="${1}" ; shift
    readonly to="${1}"   ; shift
    readonly pwd=$(pwd)

    cd ${pwd/$from/$to}
}

# Loop a command with interval (other than gnu-watch)
loop() {
    local -i sleep=10

    if [ "$SLEEP" != '' ]; then
        sleep=$SLEEP
    fi

    echo sleep is $sleep 1>&2

    while : ; do
        $@
        sleep $sleep
    done
}

lsiowait() {
    ps ax | awk '$3 ~ /D/ { print $0 }'
}

# Find helper
f() {
    find . -iname "*$@*"
}

scpf() {
    readonly src=$1
    readonly file=$2

    sudo scp -r $USER@$src:$(pwd)/$file $file
}

cpf() {
    readonly src=$1
    readonly file=$2

    scp -r $USER@$src:$(pwd)/$file $file
}

commit_message() {
    if [ -z "$1" ]; then
        which fortune && message="$(fortune)" || message='Quick commit'
    else
        message="$@"
    fi

    echo "$message"
}

gc() {
    git pull
    git commit -a -m "$(commit_message "$@")"
    git push
}

sc() {
    svn up
    svn commit -m "$(commit_message "$@")"
}

sm() {
    svn commit -m "$(commit_message "$@")"
}

mmaps() {
    readonly pid=$1
    sudo cat /proc/$pid/maps | awk '/\// {print $6}' | sort | uniq
}

# Time helpers

random() {
    local -i upto=$1
    local -i random=$[$RANDOM % $upto]
    echo "Sleeping $random seconds"
    sleep $random
}

dedup () {
    local -r file=$1

    if [ -z $file ]; then
        awk '{  if (line[$0] != 42) { print $0 }; line[$0] = 42; }'

    else
        awk '{  if (line[$0] != 42) { print $0 }; line[$0] = 42; }' $file | sudo tee $file.dedup > /dev/null || return 3
        if [ ! -f $file.dedupbak ]
        then
            sudo mv $file $file.dedupbak
        fi
        sudo mv $file.dedup $file
        wc -l $file $file.dedupbak
        sudo gzip --best $file.dedupbak &
    fi
}

dedup_no_bak () {
    local -r file=$1

    if [ -z $file ]; then
        awk '{  if (line[$0] != 42) { print $0 }; line[$0] = 42; }'

    else
        awk '{  if (line[$0] != 42) { print $0 }; line[$0] = 42; }' $file | sudo tee $file.dedup > /dev/null || return 3
        if [ ! -f $file.dedupbak ]
        then
            sudo mv $file $file.dedupbak
        fi
        sudo mv $file.dedup $file
        wc -l $file $file.dedupbak
        sudo rm -v $file.dedupbak &
    fi
}

json () {
    ruby -r json -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))'
}

drop_caches () {
    echo 3 | sudo tee /proc/sys/vm/drop_caches
}

ssl_connect () {
    local -r address=$1
    openssl s_client -connect $address
}

ssl_dates () {
    ssl_connect $@ | openssl x509 -noout -dates
}

asum () {
    awk '{ sum += $1 } END { print sum }'
}

lastu () {
   last | egrep -v '(root|cron|nagios)'
}

lastl () {
   lastu | less
}

duckduckgo () {
    lynx "https://lite.duckduckgo.com/lite?q=$*"
}

stopwatch () {
    local -i start_time=$(date +%s) 
    while :
    do
        local -i now_time=$(date +%s) 
        local -i diff_time=$(( now_time - start_time )) 
        local -i minutes=$(printf "%d" $((diff_time / 60))) 
        clear
        figlet <<< "$minutes min."
        sleep 60
    done
}

# Curl commands
weather () {
    curl http://wttr.in/
}

alias wetter=weather

cheat () {
    curl cheat.sh/$1
}

functions () {
    grep -h -E '^[a-z]+::[a-z]+ ()' ~/.zsh*/* | cut -d: -f1 | sort -u
}

alias tf=terraform
