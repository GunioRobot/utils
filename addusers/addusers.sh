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

usage ()
{
    errx 1 "usage: adduser.sh foo.tar bar.tar ..."
}

create_user_account ()
{
    user_tarball=$1
    [ -z "$user_tarball" ] && usage || :
    user_name=`echo $user_tarball | sed -e 's/\.tar//'`
    grep $user_name /etc/passwd
    if [ $? = "0" ]; then
        warnx "$user_name already exists."
        return
    fi
    exec_command tar -C /home -xpf $user_tarball
    uid_file="/home/$user_name/uid"
    uid=`cat $uid_file`
    [ -z "$uid" ] && errx 1 "uid is empty." || exec_command rm $uid_file
    gid_file="/home/$user_name/gid"
    gid=`cat $gid_file`
    [ -z "$gid" ] && errx 1 "gid is empty." || exec_command rm $gid_file
    shadow_file="/home/$user_name/shadow"
    shadow=`cat $shadow_file`
    [ -z "$shadow" ] && errx 1 "shadow is empty." || exec_command rm $shadow_file
    exec_command groupadd -g $gid $user_name
    exec_command useradd -u $uid -g $gid $user_name 
    ed /etc/shadow <<EOF
/^$user_name:/
d
w
q
EOF
    echo $shadow >> /etc/shadow
    ed /etc/group <<EOF
/^admin:/
s/$/,$user_name/
w
q
EOF
}

[ ! -x "/bin/ed" ] && errx 1 "ed not found." || :

for user_tarball in $@; do
    create_user_account $user_tarball
done

