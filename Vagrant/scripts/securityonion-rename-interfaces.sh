#!/bin/bash
echo "Renaming interfaces for consistency"
for NIC in $(ip link | grep -E 'ens|eth[0-9]{1,}|enp'| cut -d\: -f2 ); do
    if [ "$NIC" == "ens192"  ]; then
        echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"vagrant0\"" > /etc/udev/rules.d/70-persistent-net.rules
    elif [ "$NIC" == "ens32"  ]; then
        echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens33\"" >> /etc/udev/rules.d/70-persistent-net.rules
    elif [ "$NIC" == "ens33"  ]; then
        echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens34\"" >> /etc/udev/rules.d/70-persistent-net.rules
    else
        echo "Improperly named interface not found"
    fi
done
