#!/bin/sh

errx ()
{
    r=$1
    shift
    echo "$@" 1>&2
    # detach_all_lodevs
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
    if [ $retval != 0 ]; then
        errx $retval $@ exit with code $retval
    fi
}

usage ()
{
    echo "usage: clonevmimage src_logical_volume dst_logical_volume"
    exit 1
}

srclv=$1
dstlv=$2

if [ -z $srclv -o -z $dstlv ]; then
    usage
fi
if [ ! -b $srclv ]; then
    errx 1 "$srclv is not block device."
fi
if [ ! -b $dstlv ]; then
    errx 1 "$dstlv is not block device."
fi

exec_cmd losetup -f $srclv
srclodev=`losetup -a | grep $srclv | awk -F ':' '{ print $1 }'`
exec_cmd kpartx -a $srclodev
srcpart='/dev/mapper/'`echo $srclodev | sed -e 's/\/dev\///'`'p1'
exec_cmd e2fsck -f $srcpart
exec_cmd resize2fs -M $srcpart
exec_cmd e2fsck -f $srcpart

blocksize=`dumpe2fs -h $srcpart | grep 'Block size:' | sed -e 's/Block size:\ \+//g'`
blockcount=`dumpe2fs -h $srcpart | grep 'Block count:' | sed -e 's/Block count:\ \+//g'`
ddcount=`expr $blockcount + 1`

exec_cmd dd if=$srclv of=$dstlv bs=$blocksize count=$ddcount

exec_cmd resize2fs $srcpart
exec_cmd e2fsck -f $srcpart
exec_cmd kpartx -d $srclodev
exec_cmd losetup -d $srclodev

exec_cmd losetup -f $dstlv
dstlodev=`exec_cmd losetup -a | grep $dstlv | awk -F ':' '{ print $1 }'`
exec_cmd kpartx -a $dstlodev
dstpart='/dev/mapper/'`echo $dstlodev | sed -e 's/\/dev\///'`'p1'
exec_cmd e2fsck -f $dstpart
exec_cmd resize2fs $dstpart
exec_cmd e2fsck -f $dstpart
exec_cmd kpartx -d $dstlodev
exec_cmd losetup -d $dstlodev
