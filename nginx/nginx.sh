#!/bin/sh
#
# chkconfig: 2345 99 15
# description: Fast web-server and reverse proxy
# processname: /usr/local/nginx/sbin/nginx
# pidfile: /usr/local/nginx/logs/nginx.pid

PREFIX="/home/www"
NGINX="${PREFIX}/nginx/sbin/nginx"
PIDFILE="${PREFIX}/var/run/nginx.pid"
CONFFILE="${PREFIX}/etc/nginx/nginx.conf"

configtest ()
{
    $NGINX -t -c $CONFFILE
    return $?
}

start ()
{
    $NGINX -c $CONFFILE
    return $?
}

stop ()
{
    /bin/kill `/bin/cat $PIDFILE`
    return $?
}

reload ()
{
    /bin/kill -HUP `/bin/cat $PIDFILE`
    return $?
}

rotate ()
{
    /bin/kill -USR1 `/bin/cat $PIDFILE`
    return $?
}

status ()
{
    if [ -e $PIDFILE ]; then
        echo 'nginx is running. pid = '`/bin/cat $PIDFILE`'.'
    else
        echo 'nginx is not running.'
    fi
}

case "$1" in
    check|conftest|configtest)
        configtest
        retval=$?
        ;;
    start)
        configtest
        retval=$?
        [ $retval = 0 ] && start ||:
        ;;
    stop)
        stop
        retval=$?
        ;;
    reload)
        configtest
        retval=$?
        [ $retval = 0 ] && reload ||:
        ;;
    rotate)
        rotate
        retval=$?
        ;;
    restart)
        stop
        configtest
        retval=$?
        [ $retval = 0 ] && start ||:
        ;;
    status)
        status
        ;;
    *)
    echo $"Usage: $prog {start|stop|restart|status|configtest|reload|restart|}"
    retval=1
esac

exit $retval
