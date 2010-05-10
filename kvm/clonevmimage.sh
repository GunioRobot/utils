#!/bin/sh

usage ()
{
    echo "usage: clonevmimage src_logical_volume dst_logical_volume"
    exit 1
}

associated_lodevs=
add_associated_lodev ()
{
    associated_lodevs="$associated_lodevs $1"
}

release_all_associated_lodevs ()
{
    for lodev in $associated_lodevs; do
        losetup -d $lodev
    done
}

mapped_lodevs=
add_mapped_lodev ()
{
    mapped_lodevs="$mapped_lodevs $1"
}

release_all_mapped_lodevs ()
{
    for lodev in $mapped_lodevs; do
        kpartx -d $lodev
    done
}

errx ()
{
    r=$1
    shift
    echo "$@" 1>&2
    release_all_mapped_lodevs
    release_all_associated_lodevs
    exit $r
}

warnx ()
{
    echo "$@" 1>&2
}

exec_cmd ()
{
    warnx $@
    eval $@
    retval=$?
    if [ $retval != "0" ]; then
        errx $retval $@ exit with code $retval
    fi
}

detect_lodev ()
{
    lv=$1
    if [ -z $lv ]; then
        errx 1 "logical volume name is empty."
    fi
    losetup -a | grep $lv | awk -F ':' '{ print $1 }'
}

associate_lodev ()
{
    lv=$1
    if [ -z $lv ]; then
        errx 1 "logical volume name is empty."
    fi
    if [ ! -b $lv ]; then
        errx 1 "$lv is not a block device."
    fi
    if [ `losetup -a | grep "($lv)" | wc -l` != 0 ]; then
        errx 1 "$lv already associated."
    fi
    exec_cmd losetup -f $lv
    lodev=`detect_lodev $lv`
    add_associated_lodev $lodev
    echo $lodev
}

part_path ()
{
    lodev=$1
    echo '/dev/mapper/'`echo $lodev | sed -e 's/\/dev\///'`'p1'
}

map_lodev ()
{
    lodev=$1
    exec_cmd kpartx -a $lodev
    add_mapped_lodev $lodev
}

resizefs ()
{
    part=$1
    mode=$2
    resize2fs_opt=
    if [ ! -b $part ]; then
        errx 1 "$part is not a block device."
    fi
    if [ $mode = "restore" ]; then
        resize2fs_opt=""
    elif [ $mode = "shrink" ]; then
        resize2fs_opt="-M"
    else
       errx 1 "2nd option of resizefs() must be restore or shrink."
    fi
    exec_cmd e2fsck -f $part
    exec_cmd resize2fs $resize2fs_opt $part
    exec_cmd e2fsck -f $part
}

srclv=$1
dstlv=$2

if [ -z $srclv -o -z $dstlv ]; then
    usage
fi

associate_lodev $srclv
srclodev=`detect_lodev $srclv`
if [ -z $srclodev ]; then
    errx 1 "source loop device is empty."
fi
associate_lodev $dstlv
dstlodev=`detect_lodev $dstlv`
if [ -z $dstlodev ]; then
    errx 1 "destination loop device is empty."
fi

map_lodev $srclodev
srcpart=`part_path $srclodev`
resizefs $srcpart shrink

blocksize=`dumpe2fs -h $srcpart | grep 'Block size:' | sed -e 's/Block size:\ \+//g'`
blockcount=`dumpe2fs -h $srcpart | grep 'Block count:' | sed -e 's/Block count:\ \+//g'`
ddcount=`expr $blockcount + 1`
exec_cmd dd if=$srclv of=$dstlv bs=$blocksize count=$ddcount

resizefs $srcpart restore

map_lodev $dstlodev
dstpart=`part_path $dstlodev`
resizefs $dstpart restore

release_all_mapped_lodevs
release_all_associated_lodevs
