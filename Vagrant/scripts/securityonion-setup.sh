#!/bin/bash

setup_analyst() {
  if [ $(grep -c 'analyst:' /etc/passwd) -ne 0 ]; then
    echo "'analyst' user has already been added... Skipping"
  else
    # Add analyst user to align with labs
    useradd analyst -s /bin/bash -m -d /home/analyst
    echo analyst:analyst | chpasswd
    usermod -aG sudo analyst
  fi
}

fix_vagrant_ip() {
  if grep -q 'Security Onion setup' /etc/network/interfaces; then
    echo "Interfaces already configured... Skipping"
  else
    ETH_DHCP=$(ip link | grep -E 'vagrant0' | cut -f 2 -d\: | tr -d [:space:])
    DHCP_IP=$(ifconfig $ETH_DHCP | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ ! -z "$DHCP_IP" ]; then
      echo "Adding vagrant host address to Wazuh whitelist"
      VAGRANT_HOST=$(echo $DHCP_IP | awk -F. '{ print $1"."$2"."$3".2" }')
      /usr/sbin/so-ossec-stop
      sed -i  "/<white_list>127.0.0.1<\/white_list>/a \ \ \ \ <white_list>$VAGRANT_HOST<\/white_list>" /var/ossec/etc/ossec.conf
      #echo "Restarting the Wazuh server"
      #/usr/sbin/so-ossec-start
    fi
    if [ -z "$DHCP_IP" ]; then
      echo "Incorrect IP Address settings detected... Attempting to update"
      echo "" >> /etc/network/interfaces
      echo "auto $ETH_DHCP" >> /etc/network/interfaces
      echo "iface $ETH_DHCP inet dhcp" >> /etc/network/interfaces
    fi
  fi
}

fix_promisc_nic() {
  HOST=$(hostname)
  if [[ "$HOST" == "sosensor"* || "$HOST" == "securityonion" ]]; then
    ETH_PROMISC=$(ip link | grep -E 'ens34|enp0s8|eth1' | cut -f 2 -d\: | tr -d [:space:])
    echo "" >> /etc/network/interfaces
    echo "auto $ETH_PROMISC" >> /etc/network/interfaces
    echo "iface $ETH_PROMISC inet manual" >> /etc/network/interfaces
    echo "  up ip link set \$IFACE promisc on arp off up" >> /etc/network/interfaces
    echo "  down ip link set \$IFACE promisc off down" >> /etc/network/interfaces
    echo "  post-up for i in rx tx sg tso ufo gso gro lro; do ethtool -K \$IFACE \$i off; done" >> /etc/network/interfaces
    echo "  post-up echo 1 > /proc/sys/net/ipv6/conf/\$IFACE/disable_ipv6" >> /etc/network/interfaces
    echo "  # You probably don't need to enable or edit the following setting," >> /etc/network/interfaces
    echo "  # but it is included for completeness." >> /etc/network/interfaces
    echo "  # Note that increasing beyond the default my result in inconsistent traffic:" >> /etc/network/interfaces
    echo "  # https://taosecurity.blogspot.com/2019/04/troubleshooting-nsm-virtualization.html" >> /etc/network/interfaces
    echo "  # post-up ethtool -G \$IFACE rx 4096" >> /etc/network/interfaces
  fi
}

fix_static_ip() {
  if grep -q 'Security Onion setup' /etc/network/interfaces; then
    echo "Interfaces already configured... Skipping"
  else
    HOST=$(hostname)
    # Fix mgmt nic if the IP isn't set correctly
    ETH_IP=$(ip link | grep -E 'ens33|enp0s3|eth0' | cut -f 2 -d\: | tr -d [:space:])
    MGMT_IP=$(ifconfig $ETH_IP | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [[ "$MGMT_IP" != "172.16.163."* ]]; then
      echo "Incorrect IP Address settings detected... Attempting to update"
      cp /usr/share/securityonion/securityonion_setup_again.jpg /usr/share/securityonion/securityonion.jpg
      cp /etc/network/interfaces /etc/network/interfaces.bak
      echo "" >> /etc/network/interfaces
      echo "auto $ETH_IP" >> /etc/network/interfaces
      echo "iface $ETH_IP inet static" >> /etc/network/interfaces
      if [ "$HOST" == "somaster" ]; then
        echo "  address 172.16.163.200" >> /etc/network/interfaces
      elif [ "$HOST" == "sostorage01" ]; then
        echo "  address 172.16.163.215" >> /etc/network/interfaces
      elif [ "$HOST" == "sosensor01" ]; then
        echo "  address 172.16.163.210" >> /etc/network/interfaces
      elif [ "$HOST" == "sosensor02" ]; then
        echo "  address 172.16.163.220" >> /etc/network/interfaces
      elif [ "$HOST" == "soanalyst01" ]; then
        echo "  address 172.16.163.101" >> /etc/network/interfaces
        cp /usr/share/securityonion/securityonion_setup.jpg /usr/share/securityonion.jpg
      elif [ "$HOST" == "securityonion" ]; then
        echo "  address 172.16.163.225" >> /etc/network/interfaces
      fi
      echo "  netmask 255.255.255.0" >> /etc/network/interfaces
      echo "  gateway 172.16.163.222" >> /etc/network/interfaces
      echo "  post-up route del default" >> /etc/network/interfaces
      echo "  post-up route add default gw 172.16.163.222" >> /etc/network/interfaces
      echo "  dns-nameservers 172.16.163.222" >> /etc/network/interfaces
      fix_promisc_nic
      sed -i '1i # this configuration was created by the Security Onion setup script.\n' /etc/network/interfaces
    fi
    #systemctl restart networking
  fi
}

setup_testing() {
  HOST=$(hostname)
  if [ "$HOST" != "securityonion" ]; then
    # Add test files if in dev mode
    if [ -f /vagrant/resources/securityonion/00proxy ]; then
      cp /vagrant/resources/securityonion/00proxy /etc/apt/apt.conf.d/00proxy
    fi

    if [ -f /vagrant/resources/securityonion/daemon.json ]; then
      mkdir /etc/docker
      cp /vagrant/resources/securityonion/daemon.json /etc/docker/daemon.json
    fi
  fi

  # Add testing repo for newer packages/containers
  #echo 'yes' | add-apt-repository -y ppa:securityonion/test

  # Update if you'd like
  #sudo /usr/sbin/soup -y
}

enable_features() {
  if grep -q 'securityonionsolutionselas' /etc/nsm/elasticdownload.conf; then
    echo "Elastic Features already enabled... Skipping"
  else
    HOST=$(hostname)
    if [ "$HOST" == "securityonion" ]; then
      sed -i 's/securityonionsolutions/securityonionsolutionselas/' /etc/nsm/elasticdownload.conf
    fi
  fi
}

setup_analyst
setup_testing
enable_features
fix_vagrant_ip
fix_static_ip