#!/bin/sh -x

## Default Config ##
VMPATH=/opt/Vmin
DEFAULT_EDITOR=vi
DEFAULT_DISK_DRIVER=virtio
HV=$(which qemu-system-x86_64)
VIRTBR=br0
VIRTBRIP=9.8.7.1
VIRTBRNET=255.255.255.0
USE_VNC=yes
NAT_INTERFACE=eth0
DHCP_IP_START=2
DHCP_IP_END=30
## Config PATH End ##

## Utils ##
_prettytable_char_top_left="+"
_prettytable_char_horizontal="="
_prettytable_char_vertical="|"
_prettytable_char_bottom_left="+"
_prettytable_char_bottom_right="+"
_prettytable_char_top_right="+"
_prettytable_char_vertical_horizontal_left="|"
_prettytable_char_vertical_horizontal_right="|"
_prettytable_char_vertical_horizontal_top="="
_prettytable_char_vertical_horizontal_bottom="="
_prettytable_char_vertical_horizontal="|"


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
    if [ "$1" == "" ]; then
        fail_msg "Please supply VM name"
        exit 1
    fi
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
gen_ip()
{
    allIP=( $DHCP_IP_START )
    for vm in $(find $VMPATH/* -type d); do
        while read LINE; do declare local $LINE; done < $vm/vmin.conf
        if [ ! "$ip" == "" ]; then
            allIP+=($(echo $ip| rev | cut -d "." -f1 | rev))
        fi
    done
    local slk=`expr ${allIP[-1]} + 1`
    local startip=$(IFS=. read ip1 ip2 ip3 ip4 <<< "$VIRTBRIP"; echo "$ip1.$ip2.$ip3.$slk")
    echo $startip
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
    use_vnc=$USE_VNC
    disk_driver=$DEFAULT_DISK_DRIVER
    while read LINE; do declare local $LINE; done < $VMPATH/$1/vmin.conf
	if [ ! "$2" == "" ]; then
	   cdrom="-boot d -cdrom $2"
	fi
	if [ ! "$3" == "" ]; then
        cdrom+=" -drive file=$3,if=ide,media=cdrom"
    fi
    disk="-drive file=$VMPATH/$1/disk.img,if=$disk_driver,media=disk,format=raw"

    if [[ ! "$use_vnc" == "" && "$use_vnc" == "yes" ]]; then
        vnc="-vnc :$(get_vnc_port)"
    fi

    net="-netdev tap,id=n1,script=$VMPATH/qemu-ifup -device e1000,netdev=n1,mac=$mac"

    setupdhcp

    $HV $vnc -enable-kvm -daemonize -m $memory -smp cores=$vcpu -pidfile $VMPATH/$1/PID $disk $cdrom $net
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

setupnetwork()
{
    chkbr=$(ip link show type bridge|grep $VIRTBR)
    if [ "$chkbr" == "" ]; then 
        ip link add $VIRTBR type bridge
    else
        ip link delete $VIRTBR
        ip link add $VIRTBR type bridge
    fi
    ip link set $VIRTBR up
    ip addr add $VIRTBRIP/$VIRTBRNET dev $VIRTBR

    cat << EOF > $VMPATH/qemu-ifup
#!/bin/sh

if [ -n "\$1" ];then
        ip tuntap add \$1 mode tap user `whoami`
        ip link set \$1 up
        sleep 0.5s
        ip link set \$1 master $VIRTBR
        exit 0
    else
        echo "Error: no interface specified"
        exit 1
fi
EOF
    chmod +x $VMPATH/qemu-ifup
}

setupnat()
{
    sysctl net.ipv4.ip_forward=1
    iptables -t nat -D POSTROUTING -o $NAT_INTERFACE -j MASQUERADE
    iptables -t nat -A POSTROUTING -o $NAT_INTERFACE -j MASQUERADE
}

setupdhcp()
{
    local startip=$(IFS=. read ip1 ip2 ip3 ip4 <<< "$VIRTBRIP"; echo "$ip1.$ip2.$ip3.$DHCP_IP_START")
    local endip=$(IFS=. read ip1 ip2 ip3 ip4 <<< "$VIRTBRIP"; echo "$ip1.$ip2.$ip3.$DHCP_IP_END")
    local dhcpmember=""
    for vm in $(find $VMPATH/* -type d); do
        while read LINE; do declare local $LINE; done < $vm/vmin.conf
        local vm=${vm##*/}
        if [[ ! "$ip" == "" && ! "$mac" == "" ]]; then
            local dmn=$(echo $vm| tr '[:upper:]' '[:lower:]')
            dhcpmember+="dhcp-host=$mac,$ip,$dmn.slk,1d\n"
        fi
    done
    dhcpmember=$(printf $dhcpmember)
    cat <<EOF> $VMPATH/dnsmasq.conf
interface=$VIRTBR
except-interface=lo
domain=slk
dhcp-range=$startip,$endip,$VIRTBRNET,12h
dhcp-authoritative
dhcp-leasefile=$VMPATH/dnsmasq.leases

$dhcpmember
EOF
if [ -f $VMPATH/dnsmasq.pid ]; then
    kill $(cat $VMPATH/dnsmasq.pid)
fi 
rm -rf $VMPATH/dnsmasq.leases
dnsmasq --conf-file=$VMPATH/dnsmasq.conf --pid-file=$VMPATH/dnsmasq.pid
}

list()
{
	is_setup_done
    vmcount=$(find $VMPATH -maxdepth 1 -type d | wc -l)
    if [ $vmcount -eq 1 ]; then
    	begin_msg "You don't have VM yet, please create one with command \"$0 create\" !!" console
        exit 0 
    fi
	DATA='PID\tName\tMac Address\tIP Address\tVNC\tMemory\tvCPU\tDisk\tState\n'
    for vm in $(ls -d $VMPATH/*/); do
        local vm=$(echo $vm|rev|cut -d "/" -f2|rev)
        local use_vnc=$USE_VNC
        while read LINE; do declare local $LINE; done < $VMPATH/$vm/vmin.conf
        if [ -f "$VMPATH/$vm/PID" ]; then
        	local vmpid=$(cat $VMPATH/$vm/PID)
            local state="Running"
            if [[ ! "$use_vnc" == "" && "$use_vnc" == "no" ]]; then
                local vnc="VNC Disable"
            else
                local vnc=$(ss -antlp | grep "pid=$vmpid" | awk '{print $4}')
            fi
        else
			local vmpid="None"
            local state="Stopped"
            local vnc="None"
        fi
	    DATA+="$vmpid\t$vm\t$mac\t$ip\t$vnc\t$memory\t$vcpu\t$disk\t$state\n"
    done
    echo -e $DATA | prettytable 9 blue
}

create()
{
    until read -p "VM name: " -e vmname && test "$vmname" != ""; do
    	continue
    done
    local default_mac=$(gen_mac)
    local default_ip=$(gen_ip)
    read -p "MAC Address [$default_mac]: " -e mac
    : ${mac:=$default_mac}
    read -p "IP Address [$default_ip]: " -e ip
    : ${ip:=$default_ip}
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
ip=$ip
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
    start $2 $3 $4
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
    case "$2" in
        network)
            setupnetwork
        ;;
        nat)
            setupnat
        ;;
        dhcp)
            setupdhcp
        ;;
        base)
            setup
        ;;
        *)
            echo "Usage: $0 setup {base|network|nat|dhcp}"
            exit 1
    esac
    exit 0
    ;;
destroy)
    destroy $2
    ;;
create)
    create
    ;;
test)
    gen_ip
    ;;
*)
    echo "Usage: $0 {create|start|stop|restart|setup|list|destroy}"
    exit 1
esac
exit 0
