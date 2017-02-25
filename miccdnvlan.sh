#!/bin/bash

nukeAndCreateVIF () {
    # $0 netdev
    # $1 dot1q tag
    # $2 team
    # $3 network e.g. lan, dmz, or wan

    if /sbin/ifconfig ${1}.${2} down 2&>1 >/dev/null; then
	/sbin/vconfig rem ${1}.${2} 2&>1 > /dev/null
    fi

    if /sbin/ifconfig team${3}${4} down 2&>1 >/dev/null; then
	/sbin/vconfig rem team${3}${4} 2&>1 > /dev/null
    fi

    /sbin/vconfig add ${1} ${2} 2&>1 > /dev/null
    /sbin/ip link set ${1}.${2} name team${3}${4}
    /sbin/ip link set team${3}${4} up
}

WANVLANS=(430 432 433 436 437 439 520 522 529 530 532 533) 
DMZVLANS=(550 552 554 556 558 560 562 564 566 568 570 572)
LANVLANS=(551 553 555 557 559 561 563 565 567 569 571 573)

NETDEV=${1:-eth0}

if  /sbin/ifconfig ${NETDEV} 2&>1 >/dev/null ; then
    echo "Using ${NETDEV}." 
else
    echo "Device ${NETDEV} not found - are you using systemd? This is what you get." 
fi

/sbin/modprobe 8021q
/sbin/vconfig set_name_type DEV_PLUS_VID_NO_PAD

for VLAN in {0..11}; do
    echo -n Team ${VLAN}
    nukeAndCreateVIF ${NETDEV} ${WANVLANS[VLAN]} ${VLAN} wan
    echo -n " wan"
    nukeAndCreateVIF ${NETDEV} ${DMZVLANS[VLAN]} ${VLAN} dmz
    echo -n " dmz"
    nukeAndCreateVIF ${NETDEV} ${LANVLANS[VLAN]} ${VLAN} lan
    echo " lan"
done

