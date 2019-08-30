#! /bin/bash

setup_test_repo() {
  # Add testing repo for newer packages/containers
  echo "Adding test repository if enabled"
  #echo 'yes' | add-apt-repository -y ppa:securityonion/test

  # Update if you'd like
  #sudo /usr/sbin/soup -y
}

enable_features() {
  # Enable Elastic Features
  if grep -q 'securityonionsolutionselas' /etc/nsm/elasticdownload.conf; then
    echo "Elastic Features already enabled... Skipping"
  else
    HOST=$(hostname)
    if [ "$HOST" == "securityonion" ]; then
      sed -i 's/securityonionsolutions/securityonionsolutionselas/' /etc/nsm/elasticdownload.conf
    fi
  fi
}

install_securityonion() {
  if [ ! -f /etc/nsm/servertab ]; then
    # Place any testing you'd like here
    echo "Beginning standalone installation of Security Onion"
    echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/standalone.conf
    cp /usr/share/securityonion/securityonion_default.jpg /usr/share/securityonion.jpg
    # Copy over 6000 series scripts for host logs being worked on
    cp /vagrant/resources/securityonion/6*.conf /etc/logstash/custom/
    /usr/sbin/so-logstash-restart
    # Add firewall rule for host (like whitelist)
    echo "Adding firewall rule for WEF beats"
    sed -i '/containers/a -I DOCKER-USER ! -i docker0 -o docker0 -s 172.16.163.212 -p tcp --dport 5044 -j ACCEPT\n' /etc/ufw/after.rules
    systemctl restart ufw
  fi
}

setup_test_repo
enable_features
install_securityonion