#! /bin/bash

copy_logstash_custom() {
  if ls /vagrant/resources/lagniappe/[0-9]*.conf > /dev/null; then
    echo "Copy custom logstash configs"
    cp /vagrant/resources/lagniappe/[0-9]*.conf /etc/logstash/custom/
    /usr/sbin/so-logstash-restart
  fi
}

copy_bro_custom() {
  if ls /vagrant/resources/lagniappe/*.bro > /dev/null; then
    echo "Copy custom bro scripts"
    mkdir -p /opt/bro/share/bro/policy/filters
    cp /vagrant/resources/lagniappe/*.bro /opt/bro/share/bro/policy/filters/
    echo -e '\n#Custom bro filters\n@load filters' >> /opt/bro/share/bro/site/local.bro
    /opt/bro/bin/broctl stop && /opt/bro/bin/broctl deploy
  fi
}

copy_bpf_custom() {
  if [ -f /vagrant/resources/lagniappe/bpf.conf ]; then
    echo "Copy custom bpf.conf"
    cp /vagrant/resources/lagniappe/bpf.conf /etc/nsm/rules/bpf.conf
    /usr/sbin/so-sensor-restart
  fi
}

alter_etc_profile() {
  if grep -q 'You may access' /etc/profile; then
    echo "Info already added to /etc/profile"
  else
    echo "echo -e \"\n##########################################################################\"" >> /etc/profile
    echo "echo \"You may access the Security Onion web interface at https://$(ifconfig vagrant0|grep 'inet addr:'|cut -d':' -f2 | awk '{print $1}')\"" >> /etc/profile
    echo "echo -e \"##########################################################################\n\"" >> /etc/profile
  fi
}

if [[ $HOSTNAME == *"solab" ]]; then
  if [ -d /vagrant/resources/lagniappe ]; then
    copy_logstash_custom
    copy_bro_custom
    copy_bpf_custom
  fi
  alter_etc_profile
fi