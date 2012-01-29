#!/bin/sh

mysqldctl="/home/jognote/etc/rc.d/mysqldctl"
mysql_data_lvname="/dev/snapshot.labo/mysql_data"
snapshot_lvname_prefix=$mysql_data_lvname"_snapshot_"
snapshot_lvsize="4G"
max_snapshot=5

PATH=/home/jognote/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

warnx ()
{
    echo "$@" 1>&2
}

errx ()
{
    r=$1; shift; echo "$@" 1>&2; exit $r
}

exec_cmd ()
{
    cmd="$@"
    warnx $cmd
    eval $cmd
    retval=$?
    if [ $retval != "0" ]; then
        errx $retval "'$cmd' exec failed."
    fi
}

create_snapshot ()
{
    snapshot_lvname=$snapshot_lvname_prefix`date "+%Y%m%d%H%M%S"`
    exec_cmd lvcreate -L $snapshot_lvsize -s -n $snapshot_lvname $mysql_data_lvname
}

rotate_snapshot ()
{
    snapshot_array=`lvscan | grep -E "'$snapshot_lvname_prefix[0-9]{14}'" | awk '{ print $3 }' | sed -e "s/'//g" | sort -r`
    remove_count=`expr \`echo $snapshot_array | wc -w\` - $max_snapshot`
    n=0
    for snapshot in $snapshot_array; do
        if [ $n -ge $max_snapshot ]; then
            exec_cmd lvremove -f $snapshot
        fi
        n=`expr $n + 1`
    done
}

if [ ! -e $mysqldctl ]; then
    errx 1 "$mysqldctl not found."
fi

if [ `whoami` != 'root' ]; then
    errx 2 "this program must be run as root."
fi

exec_cmd "su -c '$mysqldctl stop' jognote"
create_snapshot
exec_cmd "su -c '$mysqldctl start' jognote"
rotate_snapshot
