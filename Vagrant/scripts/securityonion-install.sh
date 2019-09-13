#! /bin/bash

setup_test_repo() {
  # Add testing repo for newer packages/containers
  echo "Adding test repository if enabled"
  echo 'yes' | add-apt-repository -y ppa:securityonion/test

  # Update if you'd like
  sudo /usr/sbin/soup -y
}

enable_features() {
  HOST=$(hostname)
  if [[ "$HOST" == *"solab" ]]; then
    # Enable Elastic Features
    if grep -q 'securityonionsolutionselas' /etc/nsm/elasticdownload.conf; then
      echo "Elastic Features already enabled... Skipping"
    else
      sed -i 's/securityonionsolutions/securityonionsolutionselas/' /etc/nsm/elasticdownload.conf
    fi
  fi
}

install_securityonion() {
  HOST=$(hostname)
  if [ ! -f /etc/nsm/servertab ]; then
    # Place any testing you'd like here
    echo "Beginning standalone installation of Security Onion"
    if [[ "$HOST" == *"solab" ]]; then
      echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/lab-standalone.conf
      # Copy over 6000 series scripts for host logs being worked on
      cp /vagrant/resources/securityonion/6*.conf /etc/logstash/custom/
      /usr/sbin/so-logstash-restart
      # Add firewall rule for host (like whitelist)
      echo "Adding firewall rule for WEF beats"
      sed -i '/containers/a -I DOCKER-USER ! -i docker0 -o docker0 -s 172.16.163.212 -p tcp --dport 5044 -j ACCEPT\n' /etc/ufw/after.rules
      systemctl restart ufw
    elif [[ "$HOST" == *"securityonion" ]]; then
      sed -i 's/\(^\tADVANCED_SETUP\=\)\"1\"/\1"0"/' /usr/sbin/sosetup
      sed -i 's/^reboot/#reboot/' /usr/sbin/sosetup-network
      sed -i 's/^\t\(read\ input\)/\t#\1/' /usr/sbin/sosetup-network
      echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/base-standalone.conf
      #echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/base-standalone.conf
      sed -i 's/^#reboot/reboot/' /usr/sbin/sosetup-network
      sed -i 's/^\t#\(read\ input\)/\t\1/' /usr/sbin/sosetup-network
      sed -i 's/\(^\tADVANCED_SETUP\=\)\"0\"/\1"1"/' /usr/sbin/sosetup
    elif [[ "$HOST" == *"sominimal" ]]; then
      sed -i 's/^reboot/#reboot/' /usr/sbin/sosetup-network
      sed -i 's/^\t\(read\ input\)/\t#\1/' /usr/sbin/sosetup-network
      echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/base-standalone.conf
      #echo yes | /usr/sbin/sosetup -f /vagrant/resources/securityonion/base-standalone.conf
      sed -i 's/^#reboot/reboot/' /usr/sbin/sosetup-network
      sed -i 's/^\t#\(read\ input\)/\t\1/' /usr/sbin/sosetup-network
      /usr/sbin/so-elastic-stop
      sed -i 's|ELASTALERT_ENABLED="yes"|ELASTALERT_ENABLED="no"|g' /etc/nsm/securityonion.conf
      echo -e "\nLOGSTASH_MINIMAL=\"yes\"" >> /etc/nsm/securityonion.conf
      ES_HEAP_SIZE="400m"
      sed -i "s/^-Xms.*/-Xms$ES_HEAP_SIZE/" /etc/elasticsearch/jvm.options
      sed -i "s/^-Xmx.*/-Xmx$ES_HEAP_SIZE/" /etc/elasticsearch/jvm.options
      CLUSTER_NAME=$(grep "cluster.name" /etc/elasticsearch/elasticsearch.yml | tail -1 | cut -d\" -f2)
      rm -f /var/log/elasticsearch/${CLUSTER_NAME}.log
      LS_HEAP_SIZE="200m"
      sed -i "s/^-Xms.*/-Xms$LS_HEAP_SIZE/" /etc/logstash/jvm.options
      sed -i "s/^-Xmx.*/-Xmx$LS_HEAP_SIZE/" /etc/logstash/jvm.options
      /usr/sbin/so-elastic-restart
    fi
    cp /usr/share/securityonion/securityonion_default.jpg /usr/share/securityonion.jpg
  fi
}

#setup_test_repo
enable_features
install_securityonion