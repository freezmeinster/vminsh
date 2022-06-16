#!/bin/sh

## CONFIG PATH ##
VMPATH=~/Vmin
DEFAULT_EDITOR=vi
HV=$(which qemu-system-x86_64)
VIRTBR=br0
## Config PATH End ##

## Utils ##
_prettytable_char_top_left="┌"
_prettytable_char_horizontal="─"
_prettytable_char_vertical="│"
_prettytable_char_bottom_left="└"
_prettytable_char_bottom_right="┘"
_prettytable_char_top_right="┐"
_prettytable_char_vertical_horizontal_left="├"
_prettytable_char_vertical_horizontal_right="┤"
_prettytable_char_vertical_horizontal_top="┬"
_prettytable_char_vertical_horizontal_bottom="┴"
_prettytable_char_vertical_horizontal="┼"


# Escape codes

# Default colors
_prettytable_color_blue="0;34"
_prettytable_color_green="0;32"
_prettytable_color_cyan="0;36"
_prettytable_color_red="0;31"
_prettytable_color_purple="0;35"
_prettytable_color_yellow="0;33"
_prettytable_color_gray="1;30"
_prettytable_color_light_blue="1;34"
_prettytable_color_light_green="1;32"
_prettytable_color_light_cyan="1;36"
_prettytable_color_light_red="1;31"
_prettytable_color_light_purple="1;35"
_prettytable_color_light_yellow="1;33"
_prettytable_color_light_gray="0;37"

# Somewhat special colors
_prettytable_color_black="0;30"
_prettytable_color_white="1;37"
_prettytable_color_none="0"

function _prettytable_prettify_lines() {
    cat - | sed -e "s@^@${_prettytable_char_vertical}@;s@\$@	@;s@	@	${_prettytable_char_vertical}@g"
}

function _prettytable_fix_border_lines() {
    cat - | sed -e "1s@ @${_prettytable_char_horizontal}@g;3s@ @${_prettytable_char_horizontal}@g;\$s@ @${_prettytable_char_horizontal}@g"
}

function _prettytable_colorize_lines() {
    local color="$1"
    local range="$2"
    local ansicolor="$(eval "echo \${_prettytable_color_${color}}")"

    cat - | sed -e "${range}s@\\([^${_prettytable_char_vertical}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${_prettytable_color_none}m@g"
}

function prettytable() {
    local cols="${1}"
    local color="${2:-none}"
    local input="$(cat -)"
    local header="$(echo -e "${input}"|head -n1)"
    local body="$(echo -e "${input}"|tail -n+2)"
    {
        # Top border
        echo -n "${_prettytable_char_top_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_top}"
        done
        echo -e "\t${_prettytable_char_top_right}"

        echo -e "${header}" | _prettytable_prettify_lines

        # Header/Body delimiter
        echo -n "${_prettytable_char_vertical_horizontal_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal}"
        done
        echo -e "\t${_prettytable_char_vertical_horizontal_right}"

        echo -e "${body}" | _prettytable_prettify_lines

        # Bottom border
        echo -n "${_prettytable_char_bottom_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_bottom}"
        done
        echo -e "\t${_prettytable_char_bottom_right}"
    } | column -t -s $'\t' | _prettytable_fix_border_lines | _prettytable_colorize_lines "${color}" "2"
}

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

is_vm_exist()
{
    if [ ! -d "$VMPATH/$1" ]; then  
        fail_msg "VM $1 doesn't exist. Please create if first !!" console
        exit 1
    fi
}

is_vm_start()
{
    if [ ! -f "$VMPATH/$1/PID" ]; then  
        fail_msg "VM $1 doesn't start. You can starting it instead" console
        exit 1
    fi
}

get_process_name()
{
	ps -p $1 -o comm=
}

gen_mac()
{
	echo 00:60:2f$(od -txC -An -N3 /dev/random|tr \  :)
}

get_vnc_port()
{
	local lastport=$(netstat -antp 2>/dev/null | grep qemu | grep "0.0.0.0" | awk '{print $4}' | cut -d ":" -f2 | sort -nr | head -1)
    if [ "$lastport" == "" ]; then
        echo 1
    else
        local realport=`expr $lastport - 5900 + 1`
        echo $realport
    fi
}
## Utils Done ##

start()
{
    is_setup_done
    is_vm_exist $1
    begin_msg "Starting VM $1" console
    while read LINE; do declare local $LINE; done < $VMPATH/$1/vmin.conf
	if [ ! "$2" == "" ]; then
	   cdrom="-boot d -cdrom $2"
	fi
    disk="-drive file=$VMPATH/$1/disk.img,if=virtio,media=disk,format=raw"
    $HV -vnc :$(get_vnc_port) -enable-kvm -daemonize -m $memory -smp cores=$vcpu -pidfile $VMPATH/$1/PID $disk $cdrom
}

stop()
{
    is_setup_done
    is_vm_exist $1
    is_vm_start $1
	kill $(cat $VMPATH/$1/PID)
    begin_msg "VM $1 stopped" console
    
}

config()
{
	is_setup_done
    is_vm_exist $1
    if [ ! "$EDITOR" == "" ]; then
    	runner=$EDITOR
    else
      	runner=$DEFAULT_EDITOR
    fi
    $runner $VMPATH/$1/vmin.conf
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

list()
{
	is_setup_done
    vmcount=$(find $VMPATH -maxdepth 1 -type d | wc -l)
    if [ $vmcount -eq 1 ]; then
    	begin_msg "You don't have VM yet, please create one with command \"$0 create\" !!" console
        exit 0 
    fi
	DATA='PID\tName\tMac Address\tVNC\tMemory\tvCPU\tDisk\tState\n'
    for vm in $(ls $VMPATH); do
        while read LINE; do declare local $LINE; done < $VMPATH/$vm/vmin.conf
        if [ -f "$VMPATH/$vm/PID" ]; then
        	local vmpid=$(cat $VMPATH/$vm/PID)
            local state="Running"
            local vnc=$(ss -antlp | grep "pid=$vmpid" | awk '{print $4}')
        else
			local vmpid="None"
            local state="Stopped"
            local vnc="None"
        fi
	    DATA+="$vmpid\t$vm\t$mac\t$vnc\t$memory\t$vcpu\t$disk\t$state\n"
    done
    echo -e $DATA | prettytable 8 blue
}

create()
{
    until read -p "VM name: " -e vmname && test "$vmname" != ""; do
    	continue
    done
    default_mac=$(gen_mac)
    read -p "MAC Address [$default_mac]: " -e mac
    : ${mac:=$default_mac}
    read -p "vCPU Count [4]: " -e vcpu
    : ${vcpu:=4}
    read -p "Memory Capacity [4G]: " -e memory
    : ${memory:=4G}
    read -p "Root Disk [20G]: " -e disk
    : ${disk:=20G}
    if [ -d "$VMPATH/$vmname" ]; then
        echo "VM name $vmname already exist !!"
        exit 0
    fi
    begin_msg "Creating VM $vmname" console
    mkdir -p $VMPATH/$vmname
    cat << EOF > $VMPATH/$vmname/vmin.conf
mac=$mac
memory=$memory
vcpu=$vcpu
disk=$disk
EOF
    qemu-img create -f raw $VMPATH/$vmname/disk.img $disk 
}

destroy()
{
	
	is_setup_done
    is_vm_exist $1
    while true; do
		read -p "Are you sure to destroy VM $1? [Y/N]: " yn
		case $yn in
			[Yy]* ) rm -rf $VMPATH/$1; break;;
			[Nn]* ) exit;;
			* ) echo "Please answer Y or N.";;
		esac
	done
}

case "$1" in
install)
    start $2 $3
    ;;
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
    list
    ;;
config)
    config $2
    ;;
setup)
    setup
    ;;
destroy)
    destroy $2
    ;;
create)
    create
    ;;
*)
    echo "Usage: $0 {create|start|stop|restart|setup|list|destroy}"
    exit 1
esac

exit 0
