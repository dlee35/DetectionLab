#!/bin/bash -eux
# credit to https://raw.githubusercontent.com/teamdfir/sift-packer/master/scripts/vmware.sh

function add_vagrant_sudoers {
    # Add vagrant user to sudoers.
    echo "==> Adding vagrant to sudoers"
    echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
    sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
}

function stop_ossec {
    # Write whitelist later
    echo "==> Disabling Wazuh"
    sudo /usr/sbin/so-ossec-stop
}

function install_vagrant_key {
    # Install vagrant key
    echo "==> Installing vagrant pub key"
    mkdir -pm 700 /home/vagrant/.ssh
    wget --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O /home/vagrant/.ssh/authorized_keys; echo ''
    chmod 0600 /home/vagrant/.ssh/authorized_keys
    chown -R vagrant:vagrant /home/vagrant/.ssh
}

function install_open_vm_tools {
    echo "==> Installing Open VM Tools"
    # Install open-vm-tools so we can mount shared folders
    sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" open-vm-tools open-vm-tools-desktop
    echo "==> exit status: $?"
    # Add /mnt/hgfs so the mount works automatically with Vagrant
    sudo mkdir -p /mnt/hgfs
    echo "==> exit status: $?"
}

function install_vmware_tools {
    apt-get purge -y open-vm-tools
    mkdir -p /mnt/hgfs

    echo "==> Installing VMware Tools"
    # Assuming the following packages are installed
    # apt-get install -y linux-headers-$(uname -r) build-essential perl

    cd /tmp
    mkdir -p /mnt/cdrom
    mount -o loop /home/${SSH_USERNAME}/linux.iso /mnt/cdrom

    VMWARE_TOOLS_PATH=$(ls /mnt/cdrom/VMwareTools-*.tar.gz)
    VMWARE_TOOLS_VERSION=$(echo "${VMWARE_TOOLS_PATH}" | cut -f2 -d'-')
    VMWARE_TOOLS_BUILD=$(echo "${VMWARE_TOOLS_PATH}" | cut -f3 -d'-')
    VMWARE_TOOLS_BUILD=$(basename ${VMWARE_TOOLS_BUILD} .tar.gz)
    echo "==> VMware Tools Path: ${VMWARE_TOOLS_PATH}"
    echo "==> VMWare Tools Version: ${VMWARE_TOOLS_VERSION}"
    echo "==> VMware Tools Build: ${VMWARE_TOOLS_BUILD}"

    tar zxf /mnt/cdrom/VMwareTools-*.tar.gz -C /tmp/
    VMWARE_TOOLS_MAJOR_VERSION=$(echo ${VMWARE_TOOLS_VERSION} | cut -d '.' -f 1)
    if [ "${VMWARE_TOOLS_MAJOR_VERSION}" -lt "10" ]; then
        /tmp/vmware-tools-distrib/vmware-install.pl -d
    else
        /tmp/vmware-tools-distrib/vmware-install.pl -f
    fi

    rm /home/${SSH_USERNAME}/linux.iso
    umount /mnt/cdrom
    rmdir /mnt/cdrom
    rm -rf /tmp/VMwareTools-*

    VMWARE_TOOLBOX_CMD_VERSION=$(vmware-toolbox-cmd -v)
    echo "==> Installed VMware Tools ${VMWARE_TOOLBOX_CMD_VERSION}"
}

add_vagrant_sudoers
stop_ossec
if [[ $PACKER_BUILDER_TYPE =~ vmware ]]; then
  install_open_vm_tools
fi
install_vagrant_key