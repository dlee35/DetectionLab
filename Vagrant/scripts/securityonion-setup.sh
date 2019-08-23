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

fix_static_ip() {
  if grep -q 'Security Onion setup' /etc/network/interfaces; then
    echo "Interfaces already configured... Skipping"
  else
    HOST=$(hostname)
    # Fix mgmt nic if the IP isn't set correctly
    ETH_IP=$(ip link | grep -E 'ens33|enp0s8|eth1' | cut -f 2 -d\: | tr -d [:space:])
    MGMT_IP=$(ifconfig $ETH_IP | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [[ "$MGMT_IP" != "172.16.163."* ]]; then
      echo "Incorrect IP Address settings detected. Attempting to fix."
      cp /etc/network/interfaces /etc/network/interfaces.bak
      sed -i '1i # This configuration was created by the Security Onion setup script.\n' /etc/network/interfaces
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
      fi
      echo "  netmask 255.255.255.0" >> /etc/network/interfaces
      echo "  gateway 172.16.163.222" >> /etc/network/interfaces
      echo "  post-up route del default" >> /etc/network/interfaces
      echo "  post-up route add default gw 172.16.163.222" >> /etc/network/interfaces
      echo "  dns-nameservers 172.16.163.222" >> /etc/network/interfaces
    fi
    service networking restart
  fi
}


setup_testing() {
  # Add test files if in dev mode
  if [ -f /vagrant/resources/securityonion/00proxy ]; then
    cp /vagrant/resources/securityonion/00proxy /etc/apt/apt.conf.d/00proxy
  fi

  if [ -f /vagrant/resources/securityonion/daemon.json ]; then
    mkdir /etc/docker
    cp /vagrant/resources/securityonion/daemon.json /etc/docker/daemon.json
  fi

  # Add testing repo for newer packages/containers
  #echo 'yes' | add-apt-repository -y ppa:securityonion/test

  # Update if you'd like
  #sudo /usr/sbin/soup -y
}

setup_analyst
setup_testing
fix_static_ip