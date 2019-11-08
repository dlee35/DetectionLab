#! /bin/bash

install_guacamole() {
  if [ -d /etc/guacamole ]; then
    echo "Guacamole already installed... Skipping"
  else
    sudo bash /vagrant/scripts/guacamole-install.sh -m mysqlpass -g guacpass -n
    cp /vagrant/resources/guacamole/user-mapping.xml /etc/guacamole/user-mapping.xml
    systemctl restart tomcat7
  fi
}

alter_etc_profile() {
  if grep -q 'You may access' /etc/profile; then
    echo "Info already added to /etc/profile"
  else
    echo "echo -e \"\n###################################################################################\"" >> /etc/profile
    echo "echo \"You may access the Guacamole web interface at http://$(ifconfig eth0|grep 'inet addr:'|cut -d':' -f2 | awk '{print $1}'):8080/guacamole\"" >> /etc/profile
    echo "echo -e \"###################################################################################\n\"" >> /etc/profile
  fi
}

fix_static_ip() {
  if grep -q 'Guacamole setup' /etc/network/interfaces; then
    echo "Interfaces already configured... Skipping"
  else
      ETH_IP=$(ip link | grep -E 'eth1' | cut -f 2 -d\: | tr -d [:space:])
      MGMT_IP=$(ifconfig $ETH_IP | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
      if [[ "$MGMT_IP" != "172.16.163."* ]]; then
        echo "Incorrect IP Address settings detected... Attempting to update"
        cp /etc/network/interfaces /etc/network/interfaces.bak
        echo "" >> /etc/network/interfaces
        echo "auto $ETH_IP" >> /etc/network/interfaces
        echo "iface $ETH_IP inet static" >> /etc/network/interfaces
        echo "  address 172.16.163.250" >> /etc/network/interfaces
        echo "  netmask 255.255.255.0" >> /etc/network/interfaces
        echo "  gateway 172.16.163.222" >> /etc/network/interfaces
        echo "  post-up route del default" >> /etc/network/interfaces
        echo "  post-up route add default gw 172.16.163.222" >> /etc/network/interfaces
        echo "  dns-nameservers 172.16.163.222" >> /etc/network/interfaces
        sed -i '1i # this configuration was created by the Guacamole setup script.\n' /etc/network/interfaces
      fi
  fi
}

allow_firewall() {
  if $(ufw status | grep -q 8080); then
    echo "UFW rule already added... Skipping"
  else
    echo y | ufw enable
    ufw allow 22
    ETH_DHCP=$(ip link | grep -E 'eth0' | cut -f 2 -d\: | tr -d [:space:])
    DHCP_IP=$(ifconfig $ETH_DHCP | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ ! -z "$DHCP_IP" ]; then
      echo "Adding analyst hosts to UFW allow"
      ANALYST_HOST=$(echo $DHCP_IP | awk -F. '{ print $1"."$2"."$3".0/24" }')
      ufw allow proto tcp from $ANALYST_HOST to any port 8080
      # TESTING
      #ufw allow proto tcp from 192.168.0.0/24 to any port 8080
    fi
    if [ -z "$DHCP_IP" ]; then
      echo "Incorrect IP Address settings detected... Attempting to update"
      echo "" >> /etc/network/interfaces
      echo "auto $ETH_DHCP" >> /etc/network/interfaces
      echo "iface $ETH_DHCP inet dhcp" >> /etc/network/interfaces
    fi
  fi
}

install_guacamole
alter_etc_profile
allow_firewall
fix_static_ip