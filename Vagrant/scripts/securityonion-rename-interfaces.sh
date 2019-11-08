#!/bin/bash

if [ ! -f /etc/udev/rules.d/70-persistent-net.rules ]; then
  echo "Renaming interfaces for consistency"
  if [[ "$HOSTNAME" == *"securityonion" || "$HOSTNAME" == *"sominimal" ]]; then
    for NIC in $(ip link | grep -E 'ens|eth[0-9]{1,}|enp'| cut -d\: -f2 ); do
        # VMware Workstation naming
        if [ "$NIC" == "ens192"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"mgmt0\"" > /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "ens32"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"promisc0\"" >> /etc/udev/rules.d/70-persistent-net.rules
        # VirtualBox naming
        elif [ "$NIC" == "enp0s3"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"mgmt0\"" > /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "enp0s8"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"promisc0\"" >> /etc/udev/rules.d/70-persistent-net.rules
        fi
    done
  else
    for NIC in $(ip link | grep -E 'ens|eth[0-9]{1,}|enp'| cut -d\: -f2 ); do
        # VMware Workstation naming
        if [ "$NIC" == "ens192"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"vagrant0\"" > /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "ens32"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens33\"" >> /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "ens33"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens34\"" >> /etc/udev/rules.d/70-persistent-net.rules
        # VirtualBox naming
        elif [ "$NIC" == "enp0s3"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"vagrant0\"" > /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "enp0s8"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens33\"" >> /etc/udev/rules.d/70-persistent-net.rules
        elif [ "$NIC" == "enp0s9"  ]; then
            echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$(cat /sys/class/net/$NIC/address)\", NAME=\"ens34\"" >> /etc/udev/rules.d/70-persistent-net.rules
        fi
    done
  fi
fi