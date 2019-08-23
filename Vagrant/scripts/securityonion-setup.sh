setup_securityonion() {
  if [ $(grep -c 'analyst:' /etc/passwd) -ne 0 ]; then
    echo "'analyst' user has already been added... Skipping"
  else
    # Add analyst user to align with labs
    useradd analyst -s /bin/bash -m -d /home/analyst
    echo analyst:analyst | chpasswd
    usermod -aG sudo analyst

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
  fi
}

setup_securityonion