#!/bin/sh

errx ()
{
    r=$1
    shift
    echo "$@" 1>&2
    exit $r
}

warnx ()
{
    echo "$@" 1>&2
}

exec_command ()
{
    warnx $@
    eval $@
    retval=$?
    if [ $retval != 0 ]; then
        errx $retval $@ exit with code $retval
    fi
}

attache_lodev ()
{
    lvname=$1
    if [ -z $lvname ]; then
        errx 1 "logical volume does not specified."
    fi
    if [ `losetup -a | grep $lvname | wc -l` != 0 ]; then
        errx 1 "$lvname already attached."
    fi
    exec_command losetup -f $lvname
    losetup -a | grep $lvname | awk -F ':' '{print $1}'
}

detach_lodev ()
{
    lodev=$1
    if [ -z $lodev ]; then
        errx 1 "loopback device does not specified."
    fi
    try=0
    max_try=10
    while [ $try -lt $max_try ]; do
        sleep 1
        cmd="losetup -d $lodev"
        warnx $cmd
        eval $cmd
        [ $? = 0 ] && break || :
        try=`expr $try + 1`
    done
    if [ $try = $max_try ]; then
        errx 1 losetup -d $lodev
    fi
}

add_partition_mappings ()
{
    lodev=$1
    if [ -z $lodev ]; then
        errx 1 "loopback device does not specified."
    fi
    if [ ! -e $lodev ]; then
        errx 1 "specified loopback device does not exist."
    fi
    exec_command kpartx -a $lodev
}

delete_partition_mappings ()
{
    lodev=$1
    if [ -z $lodev ]; then
        errx 1 "loopback device does not specified."
    fi
    if [ ! -e $lodev ]; then
        errx 1 "specified loopback device does not exist."
    fi
    try=0
    max_try=10
    while [ $try -lt $max_try ]; do
        sleep 1
        cmd="kpartx -d $lodev"
        warnx $cmd
        eval $cmd
        [ $? = 0 ] && break || :
        try=`expr $try + 1`
    done
    if [ $try = $max_try ]; then
        errx 1 kpartx -d $lodev failed.
    fi
}

detect_partition_device ()
{
    lodev=$1
    if [ -z $lodev ]; then
        errx 1 "loopback device does not specified."
    fi
    partition=/dev/mapper/`kpartx -l $lodev | grep loop | head -n 1 | awk '{print $1}'`
    echo $partition
}

shrink_filesystem ()
{
    partition_device=$1
    if [ -z $partition_device ]; then
        errx 1 "partition_device does not specified."
    fi
    exec_command e2fsck -p -f $partition_device >/dev/null
    exec_command resize2fs -M $partition_device >/dev/null
    exec_command e2fsck -p -f $partition_device >/dev/null
}

restore_filesystem ()
{
    partition_device=$1
    if [ -z $partition_device ]; then
        errx 1 "partition_device does not specified."
    fi
    exec_command e2fsck -p -f $partition_device >/dev/null
    exec_command resize2fs $partition_device >/dev/null
    exec_command e2fsck -p -f $partition_device >/dev/null
}

calc_blocks_to_dd ()
{
    partition_device=$1
    if [ -z $partition_device ]; then
        errx 1 "partition_device device does not specified."
    fi
    block_count=`dumpe2fs -h $partition_device 2>/devnull | grep 'Block count' | awk '{print $3}'`
    expr $block_count \* 4096 / 1024 / 1024 + 1
}

clone_kvm_disk ()
{
    from_lodev=$1; shift
    dest_lodev=$1; shift
    blocks_to_dd=$1; shift
    exec_command dd if=$from_lodev of=$dest_lodev bs=1M count=$blocks_to_dd
    add_partition_mappings $dest_lodev
    partition_device=`detect_partition_device $dest_lodev`
    restore_filesystem $partition_device
    delete_partition_mappings $dest_lodev
}

usage ()
{
    errx 1 usage: $0 from_lv dest_lv
}

from_lv=$1
dest_lv=$2

[ -z "$from_lv" -o -z "$dest_lv" ] && usage || :

from_lodev=`attache_lodev $from_lv`
add_partition_mappings $from_lodev
partition_device=`detect_partition_device $from_lodev`
shrink_filesystem $partition_device
blocks_to_dd=`calc_blocks_to_dd $partition_device`
dest_lodev=`attache_lodev $dest_lv`
clone_kvm_disk $from_lodev $dest_lodev $blocks_to_dd
detach_lodev $dest_lodev
restore_filesystem `detect_partition_device $from_lodev`
delete_partition_mappings $from_lodev
detach_lodev $from_lodev
