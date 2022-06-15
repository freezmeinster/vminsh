#!/bin/sh

## CONFIG PATH ##
VMPATH=~/Vmin
## Config PATH End ##

## Utils ##

begin_msg()
{
    test -n "${2}" && echo "${SCRIPTNAME}: ${1}."
    logger -t "${SCRIPTNAME}" "${1}."
}

succ_msg()
{
    logger -t "${SCRIPTNAME}" "${1}."
}

fail_msg()
{
    echo "${SCRIPTNAME}: failed: ${1}." >&2
    logger -t "${SCRIPTNAME}" "failed: ${1}."
}

is_setup_done()
{
    if [ ! -d "$VMPATH" ]; then  
        fail_msg "Please run \"$0 setup\" first before you can continue !! " console
        exit 1
    fi
}
## Utils Done ##

start()
{
    is_setup_done
    begin_msg "Starting VM $1" console
    if [ ! -d "$VMPATH/$1" ]; then
        begin_msg "We can't found VM $1, maybe wrong name ?" console
        exit 0
    fi
}

setup()
{
    begin_msg "Setuping Vmin" console
    if [ -d "$VMPATH" ]; then
        read -p "Are you sure you want to resetup Vmin? [y/n] " -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            begin_msg "We will destroy all your data now" console
        else
                begin_msg "Ok, i don't want to touch it either" console
                exit 0
        fi
    fi
    rm -rf $VMPATH
    mkdir $VMPATH

    begin_msg "Setup Done" console
}

case "$1" in
start)
    start $2
    ;;
stop)
    stop $2
    ;;
restart)
    restart $2
    ;;
restart)
    stop $2 && start $2
    ;;
list)
    ;;
setup)
    setup
    ;;
destroy)
    ;;
create)
    ;;
*)
    echo "Usage: $0 {create|start|stop|restart|setup|list|destroy}"
    exit 1
esac

exit 0
