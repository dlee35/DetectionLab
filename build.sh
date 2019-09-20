#! /bin/bash

# This script is meant to be used with a fresh clone of DetectionLab and
# will fail to run if boxes have already been created or any of the steps
# from the README have already been run followed.
# Only MacOS and Linux are supported. Use build.ps1 for Windows.
# If you encounter issues, feel free to open an issue at
# https://github.com/clong/DetectionLab/issues

print_usage() {
  echo "Usage: ./build.sh <virtualbox | vmware_desktop>  <--vagrant-only | --packer-only>"
  exit 0
}

check_packer_path() {
  # Check for existence of Packer in PATH
  if ! which packer >/dev/null; then
    (echo >&2 "Packer was not found in your PATH.")
    (echo >&2 "Please correct this before continuing. Quitting.")
    (echo >&2 "Hint: sudo cp ./packer /usr/local/bin/packer; sudo chmod +x /usr/local/bin/packer")
    exit 1
  fi
}

check_vagrant_path() {
  # Check for existence of Vagrant in PATH
  if ! which vagrant >/dev/null; then
    (echo >&2 "Vagrant was not found in your PATH.")
    (echo >&2 "Please correct this before continuing. Quitting.")
    exit 1
  fi
  # Ensure Vagrant >= 2.2.2
  # https://unix.stackexchange.com/a/285928
  VAGRANT_VERSION="$(vagrant --version | cut -d ' ' -f 2)"
  REQUIRED_VERSION="2.2.2"
  # If the version of Vagrant is not greater than the required version
  if ! [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VAGRANT_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    (echo >&2 "WARNING: It is highly recommended to use Vagrant $REQUIRED_VERSION or above before continuing")
  fi
}

# Returns 0 if not installed or 1 if installed
check_virtualbox_installed() {
  if which VBoxManage >/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
# Check for VMWare Workstation on Linux
check_vmware_workstation_installed() {
  if which vmrun >/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_fusion_installed() {
  if [ -e "/Applications/VMware Fusion.app" ]; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_desktop_vagrant_plugin_installed() {
  LEGACY_PLUGIN_CHECK="$(vagrant plugin list | grep -c 'vagrant-vmware-fusion')"
  if [ "$LEGACY_PLUGIN_CHECK" -gt 0 ]; then
    (echo >&2 "The VMware Fusion Vagrant plugin is deprecated and is no longer supported by the DetectionLab build script.")
    (echo >&2 "Please upgrade to the VMware Desktop plugin: https://www.vagrantup.com/docs/vmware/installation.html")
    (echo >&2 "NOTE: The VMware plugin does not work with trial versions of VMware Fusion")
    echo "0"
  fi
  VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT="$(vagrant plugin list | grep -c 'vagrant-vmware-desktop')"
  if [ "$VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT" -eq 0 ]; then
    (echo >&2 "VMWare Fusion or Workstation is installed, but the vagrant-vmware-desktop plugin is not.")
    (echo >&2 "If you are seeing this, you may have the deprecated vagrant-vmware-fusion plugin installed. Please remove it and install the vagrant-vmware-desktop plugin.")
    (echo >&2 "Visit https://www.hashicorp.com/blog/introducing-the-vagrant-vmware-desktop-plugin for more information on how to purchase and install it")
    (echo >&2 "VMWare Fusion or Workstation will not be listed as a provider until the vagrant-vmware-desktop plugin has been installed.")
    echo "0"
  else
    echo "$VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT"
  fi
}



# List the available Vagrant providers present on the system
list_providers() {
  VBOX_PRESENT=0
  VMWARE_FUSION_PRESENT=0

  if [ "$(uname)" == "Darwin" ]; then
    # Detect Providers on OSX
    VBOX_PRESENT=$(check_virtualbox_installed)
    VMWARE_FUSION_PRESENT=$(check_vmware_fusion_installed)
    VMWARE_WORKSTATION_PRESENT=0 # Workstation doesn't exists on Darwain-based OS
    VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT=$(check_vmware_desktop_vagrant_plugin_installed)
  else
    # Assume the only other available provider is VirtualBox
    VBOX_PRESENT=$(check_virtualbox_installed)
    VMWARE_WORKSTATION_PRESENT=$(check_vmware_workstation_installed)
    VMWARE_FUSION_PRESENT=0 # Fusion doesn't exist on non-Darwin OS
    VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT=$(check_vmware_desktop_vagrant_plugin_installed)
  fi

  (echo >&2 "Available Providers:")
  if [ "$VBOX_PRESENT" == "1" ]; then
    (echo >&2 "virtualbox")
  fi
  if [[ $VMWARE_FUSION_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT -eq 1 ]]; then
    (echo >&2 "vmware_desktop")
  fi
  if [[ $VMWARE_WORKSTATION_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT -eq 1 ]]; then
    (echo >&2 "vmware_desktop")
  fi
  if [[ $VBOX_PRESENT -eq 0 ]] && [[ $VMWARE_FUSION_PRESENT -eq 0 ]] && [[ $VMWARE_WORKSTATION_PRESENT -eq 0 ]]; then
    (echo >&2 "You need to install a provider such as VirtualBox or VMware Fusion to continue.")
    exit 1
  fi
  (echo >&2 -e "\\nWhich provider would you like to use?")
  read -r PROVIDER
  # Sanity check
  if [[ "$PROVIDER" != "virtualbox" ]] && [[ "$PROVIDER" != "vmware_desktop" ]]; then
    (echo >&2 "Please choose a valid provider. \"$PROVIDER\" is not a valid option.")
    exit 1
  fi
  echo "$PROVIDER"
}

get_lab_hosts() {
  LAB_HOSTS=($(grep '^ \{1,\}config.vm.define' $DL_DIR/Vagrant/Vagrantfile | cut -f2 -d\"))
}

get_running_hosts() {
  cd "$DL_DIR"/Vagrant/ || exit 1
  LAB_HOSTS=$(vagrant status | grep '  running' | cut -f1 -d\ )
}

# Check to see if boxes exist in the "Boxes" directory already
check_boxes_built() {
  BOXES_BUILT=$(find "$DL_DIR"/Boxes -name "*.box" | wc -l)
  if [ "$BOXES_BUILT" -gt 0 ]; then
    if [[ "$VAGRANT_ONLY" -eq 1 && "$VAGRANT_ACTION" == "up" ]]; then
      (echo >&2 "WARNING: You seem to have at least one .box file present in $DL_DIR/Boxes already. If you would like fresh boxes downloaded, please remove all files from the Boxes directory and re-run this script.")
    elif [ "$VAGRANT_ONLY" -eq 0 ]; then
      (echo >&2 "You seem to have at least one .box file in $DL_DIR/Boxes. This script does not support pre-built boxes. Please either delete the existing boxes or follow the build steps in the README to continue.")
      exit 1
    fi
  fi
}

# Check to see if any Vagrant instances exist already
check_vagrant_instances_exist() {
  cd "$DL_DIR"/Vagrant/ || exit 1
  # Vagrant status has the potential to return a non-zero error code, so we work around it with "|| true"
  VAGRANT_BUILT=$(vagrant status | grep -Ec 'created \(|running \(|poweroff \(') || true
  if [[ "$VAGRANT_BUILT" -ne "${#LAB_HOSTS[@]}" ]]; then
    echo $VAGRANT_BUILT
    echo ${#LAB_HOSTS[@]}
    (echo >&2 "You appear to have already created at least one Vagrant instance. This script does not support pre-created instances. Please either destroy the existing instances or follow the build steps in the README to continue.")
    exit 1
  fi
}

check_vagrant_reload_plugin() {
  # Ensure the vagrant-reload plugin is installed
  VAGRANT_RELOAD_PLUGIN_INSTALLED=$(vagrant plugin list | grep -c 'vagrant-reload')
  if [ "$VAGRANT_RELOAD_PLUGIN_INSTALLED" != "1" ]; then
    (echo >&2 "The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.")
    if ! $(which vagrant) plugin install "vagrant-reload"; then
      (echo >&2 "Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.")
      exit 1
    fi
  fi
}

check_vagrant_vbguest_plugin() {
  # Ensure the vagrant-vbguest plugin is installed
  VAGRANT_VBGUEST_PLUGIN_INSTALLED=$(vagrant plugin list | grep -c 'vagrant-vbguest')
  if [ "$VAGRANT_VBGUEST_PLUGIN_INSTALLED" != "1" ]; then
    (echo >&2 "The vagrant-vbguest plugin is required and not currently installed. This script will attempt to install it now.")
    if ! $(which vagrant) plugin install "vagrant-vbguest"; then
      (echo >&2 "Unable to install the vagrant-vbguest plugin. Please try to do so manually and re-run this script.")
      exit 1
    fi
  fi
}

# Check available disk space. Recommend 80GB free, warn if less.
check_disk_free_space() {
  FREE_DISK_SPACE=$(df -m "$HOME" | tr -s ' ' | grep '/' | cut -d ' ' -f 4)
  if [ "$FREE_DISK_SPACE" -lt 80000 ]; then
    (echo >&2 -e "Warning: You appear to have less than 80GB of HDD space free on your primary partition. If you are using a separate parition, you may ignore this warning.\n")
    (df >&2 -m "$HOME")
    (echo >&2 "")
  fi
}

# Check to see if curl is in PATH - needed for post-install checks
check_curl(){
  if ! which curl >/dev/null; then
    (echo >&2 "Please install curl and make sure it is in your PATH.")
    exit 1
  fi
}

# Check Packer version against known "bad" versions
check_packer_known_bad() {
  if [ "$(packer --version)" == '1.1.2' ]; then
    (echo >&2 "Packer 1.1.2 is not supported. Please upgrade to a newer version and see https://github.com/hashicorp/packer/issues/5622 for more information.")
    exit 1
  fi
}

# A series of checks to identify potential issues before starting the build
preflight_checks() {
  # If it's not a Vagrant-only build, then run Packer-related checks
  if [ "$VAGRANT_ONLY" -eq 0 ]; then
    check_packer_path
    check_packer_known_bad
  fi

  # If it's not a Packer-only build, then run Vagrant-related checks
  if [ "$PACKER_ONLY" -eq 0 ]; then
    check_vagrant_path
    check_vagrant_instances_exist
    check_vagrant_reload_plugin
    check_vagrant_vbguest_plugin
  fi

  check_boxes_built
  check_disk_free_space
  check_curl
}

# Builds a box using Packer
packer_build_box() {
  BOX="$1"
  cd "$DL_DIR/Packer" || exit 1
  (echo >&2 "Using Packer to build the $BOX Box. This can take 90-180 minutes depending on bandwidth and hardware.")
  PACKER_LOG=1 PACKER_LOG_PATH="$DL_DIR/Packer/packer_build.log" $(which packer) build --only="$PACKER_PROVIDER-iso" "$BOX".json >&2
  echo "$?"
}

# Moves the boxes from the Packer directory to the Boxes directory
move_boxes() {
  mv "$DL_DIR"/Packer/*.box "$DL_DIR"/Boxes
  # Ensure Windows 10 box exists
  if [ ! -f "$DL_DIR"/Boxes/windows_10_"$PACKER_PROVIDER".box ]; then
    (echo >&2 "Windows 10 box is missing from the Boxes directory. Qutting.")
    exit 1
  fi
  # Ensure Windows 2016 box exists
  if [ ! -f "$DL_DIR"/Boxes/windows_2016_"$PACKER_PROVIDER".box ]; then
    (echo >&2 "Windows 2016 box is missing from the Boxes directory. Qutting.")
    exit 1
  fi
}

# Brings up a single host using Vagrant
vagrant_up_host() {
  HOST="$1"
  (echo >&2 "Attempting to bring up the $HOST host using Vagrant")
  cd "$DL_DIR"/Vagrant || exit 1
  $(which vagrant) up "$HOST" --provider="$PROVIDER" &> "$DL_DIR/Vagrant/logs/vagrant_up_$HOST.log"
  echo "$?"
}

# Attempts to reload and re-provision a host if the intial "vagrant up" fails
vagrant_reload_host() {
  HOST="$1"
  cd "$DL_DIR"/Vagrant || exit 1
  # Attempt to reload the host if the vagrant up command didn't exit cleanly
  $(which vagrant) reload "$HOST" --provision >>"$DL_DIR/Vagrant/logs/vagrant_up_$HOST.log" 2>&1
  echo "$?"
}

# Attempts to shutdown a host
vagrant_halt_host() {
  HOST="$1"
  cd "$DL_DIR"/Vagrant || exit 1
  # Attempt to shutdown the host
  $(which vagrant) halt "$HOST" >>"$DL_DIR/Vagrant/logs/vagrant_halt_$HOST.log" 2>&1
  echo "$?"
}

# Attempts to delete a host
vagrant_destroy_host() {
  HOST="$1"
  cd "$DL_DIR"/Vagrant || exit 1
  # Attempt to delete the host
  $(which vagrant) destroy -f "$HOST" >>"$DL_DIR/Vagrant/logs/vagrant_destroy_$HOST.log" 2>&1
  echo "$?"
}

# A series of checks to ensure important services are responsive after the build completes.
post_build_checks() {
  # If the curl operation fails, we'll just leave the variable equal to 0
  # This is needed to prevent the script from exiting if the curl operation fails
  #SPLUNK_CHECK=$(curl -ks -m 2 https://172.16.163.105:8000/en-US/account/login?return_to=%2Fen-US%2F | grep -c 'This browser is not supported by Splunk' || echo "")
  #FLEET_CHECK=$(curl -ks -m 2 https://172.16.163.105:8412 | grep -c 'Kolide Fleet' || echo "")
  #ATA_CHECK=$(curl --fail --write-out "%{http_code}" -ks https://172.16.163.103 -m 2)
  [[ $ATA_CHECK == 401 ]] && ATA_CHECK=1

  BASH_MAJOR_VERSION=$(/bin/bash --version | grep 'GNU bash' | grep -o version\.\.. | cut -d ' ' -f 2 | cut -d '.' -f 1)
  # Associative arrays are only supported in bash 4 and up
  if [ "$BASH_MAJOR_VERSION" -ge 4 ]; then
    declare -A SERVICES
    SERVICES=(["splunk"]="$SPLUNK_CHECK" ["fleet"]="$FLEET_CHECK" ["ms_ata"]="$ATA_CHECK")
    for SERVICE in "${!SERVICES[@]}"; do
      if [ "${SERVICES[$SERVICE]}" -lt 1 ]; then
        (echo >&2 "Warning: $SERVICE failed post-build tests and may not be functioning correctly.")
      fi
    done
  else
    if [ "$SPLUNK_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Splunk failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$FLEET_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Fleet failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$ATA_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: MS ATA failed post-build tests and may not be functioning correctly.")
    fi
  fi
}

parse_cli_arguments() {
  # If no argument was supplied, list available providers
  if [[ "$#" -le 1 && "$1" == "up" ]]; then
    PROVIDER=$(list_providers)
  fi
  # If more than two arguments were supplied, print usage message
  if [ "$#" -gt 3 ]; then
    print_usage
    exit 1
  fi
  if [ "$#" -ge 1 ]; then
    # If the user specifies the provider as an agument, set the variable
    # TODO: Check to make sure they actually have their provider installed
    case "$1" in
      up)
      VAGRANT_ACTION="up"
      ;;
      halt)
      VAGRANT_ACTION="halt"
      ;;
      destroy)
      VAGRANT_ACTION="destroy"
      ;;
      *)
      echo "\"$1\" is not a valid vagrant command"
      ;;
    esac
  fi
  if [[ "$#" -ge 2 && "$1" == "up" ]]; then
    # If the user specifies the provider as an agument, set the variable
    # TODO: Check to make sure they actually have their provider installed
    case "$2" in
      virtualbox)
      PROVIDER="$2"
      PACKER_PROVIDER="$2"
      ;;
      vmware_desktop)
      PROVIDER="$2"
      PACKER_PROVIDER="vmware"
      ;;
      *)
      echo "\"$2\" is not a valid provider. Listing available providers:"
      PROVIDER=$(list_providers)
      ;;
    esac
  fi
  if [[ $# -eq 3 && "$1" == "up" ]]; then
    case "$3" in
      --packer-only)
      PACKER_ONLY=1
      ;;
      --vagrant-only)
      VAGRANT_ONLY=1
      ;;
      *)
      echo -e "\"$3\" is not recognized as an option. Available options are:\\n--packer-only\\n--vagrant-only"
      exit 1
      ;;
    esac
  fi
}

build_packer_boxes() {
  PACKER_BOXES=("windows_2016" "windows_10")

  if [ "$(hostname)" == "packerwindows10" ]; then   # Workaround for CI environment
  (echo >&2 "CI Environment detected. If you are a user and are seeing this, please file an issue on GitHub.")
  RET=$(packer_build_box "windows_10")
  if [ "$RET" -eq 0 ]; then
    (echo >&2 "Good news! The windows_10 box was built with Packer successfully!")
  else
    (echo >&2 "Something went wrong while attempting to build the windows_10 box.")
    (echo >&2 "To file an issue, please visit https://github.com/clong/DetectionLab/issues/")
    exit 1
  fi
elif [ "$(hostname)" == "packerwindows2016" ]; then  # Workaround for CI environment
(echo >&2 "CI Environment detected. If you are a user and are seeing this, please file an issue on GitHub.")
RET=$(packer_build_box "windows_2016")
if [ "$RET" -eq 0 ]; then
  (echo >&2 "Good news! The windows_2016 box was built with Packer successfully!")
else
  (echo >&2 "Something went wrong while attempting to build the windows_2016 box.")
  (echo >&2 "To file an issue, please visit https://github.com/clong/DetectionLab/issues/")
  exit 1
fi
else
  for PACKER_BOX in "${PACKER_BOXES[@]}"; do  # Normal user workflow
  RET=$(packer_build_box "$PACKER_BOX")
  if [ "$RET" -eq 0 ]; then
    (echo >&2 "Good news! $PACKER_BOX was built successfully!")
  else
    (echo >&2 "Something went wrong while attempting to build the $PACKER_BOX box.")
    (echo >&2 "To file an issue, please visit https://github.com/clong/DetectionLab/issues/")
    exit 1
  fi
done
fi
}

build_vagrant_hosts() {
  # Vagrant up each box and attempt to reload one time if it fails
  for VAGRANT_HOST in "${LAB_HOSTS[@]}"; do
    if [ "$VAGRANT_ACTION" == "up" ]; then
      RET=$(vagrant_up_host "$VAGRANT_HOST")
      if [ "$RET" -eq 0 ]; then
        (echo >&2 "Good news! $VAGRANT_HOST was built successfully!")
      fi
      # Attempt to recover if the intial "vagrant up" fails
      if [ "$RET" -ne 0 ]; then
        (echo >&2 "Something went wrong while attempting to build the $VAGRANT_HOST box.")
        (echo >&2 "Attempting to reload and reprovision the host...")
        RETRY_STATUS=$(vagrant_reload_host "$VAGRANT_HOST")
        if [ "$RETRY_STATUS" -eq 0 ]; then
          (echo >&2 "Good news! $VAGRANT_HOST was built successfully after a reload!")
        else
          (echo >&2 "Failed to bring up $VAGRANT_HOST after a reload. Exiting.")
          exit 1
        fi
      fi
    elif [ "$VAGRANT_ACTION" == "halt" ]; then
      RET=$(vagrant_halt_host "$VAGRANT_HOST")
      if [ "$RET" -eq 0 ]; then
        (echo >&2 "Good news! $VAGRANT_HOST was stopped successfully!")
      fi
      # Attempt to recover if the intial "vagrant up" fails
      if [ "$RET" -ne 0 ]; then
        (echo >&2 "Something went wrong while attempting to stop the $VAGRANT_HOST box.")
        (echo >&2 "Attempting to stop the host again...")
        RETRY_STATUS=$(vagrant_halt_host "$VAGRANT_HOST")
        if [ "$RETRY_STATUS" -eq 0 ]; then
          (echo >&2 "Good news! $VAGRANT_HOST was stopped successfully!")
        else
          (echo >&2 "Failed to stop $VAGRANT_HOST after second attempt. Exiting.")
          exit 1
        fi
      fi
    elif [ "$VAGRANT_ACTION" == "destroy" ]; then
      RET=$(vagrant_destroy_host "$VAGRANT_HOST")
      if [ "$RET" -eq 0 ]; then
        (echo >&2 "Good news! $VAGRANT_HOST was destroyed successfully!")
      fi
      # Attempt to recover if the intial "vagrant up" fails
      if [ "$RET" -ne 0 ]; then
        (echo >&2 "Something went wrong while attempting to destroy the $VAGRANT_HOST box.")
        (echo >&2 "Attempting to destroy the host again...")
        RETRY_STATUS=$(vagrant_destroy_host "$VAGRANT_HOST")
        if [ "$RETRY_STATUS" -eq 0 ]; then
          (echo >&2 "Good news! $VAGRANT_HOST was destroyed successfully!")
        else
          (echo >&2 "Failed to destroy $VAGRANT_HOST after second attempt. Exiting.")
          exit 1
        fi
      fi
    fi
  done
}

main() {
  # Get location of build.sh
  # https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
  #parse_cli_arguments "$@"
  get_lab_hosts
  preflight_checks

  # Build Packer boxes if this isn't a Vagrant-only build
  if [ "$VAGRANT_ONLY" -eq 0 ]; then
    build_packer_boxes
    # The only time we will need to move boxes is if we're doing a full build
    if [ "$PACKER_ONLY" -eq 0 ]; then
      move_boxes
    fi
  fi

  # Build and Test Vagrant hosts if this isn't a Packer-only build
  if [ "$PACKER_ONLY" -eq 0 ]; then
    build_vagrant_hosts
    #post_build_checks
  fi
}

haltmenu() {
  while [ 1 ]
  do
  CHOICE=$(
  whiptail --title "Security Onion Halt Options" --menu "Make your choice" 16 100 9 \
  	"1." "Halt Current Env  - Shutdown all machines in current environment"   \
  	"2." "Halt All Envs     - Shutdown all machines in all environments. This will take a bit."   \
  	"M." "Menu" \
  	"Q." "Quit"  3>&2 2>&1 1>&3	
  )
  
  case $CHOICE in
  	"1.")   
      CLI_ARGS=("halt")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"2.")   
      CLI_ARGS=("halt")
      parse_cli_arguments "${CLI_ARGS[@]}"
      cp $DL_DIR/Vagrant/Vagrantfile_Minimal $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Basic $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Distributed $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Lab $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_All $DL_DIR/Vagrant/Vagrantfile
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"M.") menu
      ;;
  
  	"Q.") exit
      ;;
  esac
  exit
  done
}

destroymenu() {
  while [ 1 ]
  do
  CHOICE=$(
  whiptail --title "Security Onion Destroy Options" --menu "Make your choice" 16 100 9 \
  	"1." "Destroy Current Env  - Destroy all machines in current environment"   \
  	"2." "Destroy All Envs     - Destroy all machines in all environments. This will take a bit."   \
  	"M." "Menu" \
  	"Q." "Quit"  3>&2 2>&1 1>&3	
  )
  
  case $CHOICE in
  	"1.")   
      CLI_ARGS=("destroy")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"2.")   
      CLI_ARGS=("destroy")
      parse_cli_arguments "${CLI_ARGS[@]}"
      cp $DL_DIR/Vagrant/Vagrantfile_Minimal $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Basic $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Distributed $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_Lab $DL_DIR/Vagrant/Vagrantfile
  	  main
      cp $DL_DIR/Vagrant/Vagrantfile_All $DL_DIR/Vagrant/Vagrantfile
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"M.") menu
      ;;
  
  	"Q.") exit
      ;;
  esac
  exit
  done
}

helpmenu() {
  helpspace="\n                         "
  helpmessage="1.  Minimal Install     - Single Security Onion Instance (Standalone)$helpspace NAT network$helpspace 2 interfaces: mgmt0 & promisc0$helpspace Setup to use minimal hardware: 2 CPU & 4GB RAM$helpspace Self installing. Ready to go after the initial build!$helpspace WARNING: Suricata NIDS and Bro/Zeek logs ONLY!\n\n"
  helpmessage+="2.  Standard Install    - Single Security Onion Instance (Standalone)$helpspace NAT network$helpspace 2 interfaces: mgmt0 & promisc0$helpspace Setup to use basic requirements for eval: 4 CPU & 8GB RAM$helpspace Self installing. Ready to go after the initial build!$helpspace Full Elastic pipeline and standard integrations\n\n"
  helpmessage+="3.  Distributed Demo    - Analyst, Master, Heavy, Forward, pfSense, Apt-Cacher NG, Web, DC$helpspace 172.16.163.0/24 network$helpspace Vanilla installation without any setup$helpspace Learn how a distributed Security Onion installation works$helpspace Integrate any endpoint solution for testing\n\n"
  helpmessage+="4.  Windows Lab         - Security Onion (Standalone), pfSense, RTO, DC, WEF, Win10$helpspace 172.16.163.0/24 network$helpspace Security Onion setup complete w/Elastic Features enabled$helpspace Red Team Operator machine using Redcloud and educational ransomware,$helpspace Sysmon, Autoruns, Atomic Red Team, Mimikatz installed on Windows$helpspace All Windows logs forwarded to WEF box via GPO$helpspace WEF forwards all logs to Security Onion via Winlogbeat\n\n"
  helpmessage+="5.  All Machines        - The whole enchilada! Please have at least 64GB of RAM to attempt$helpspace 172.16.163.0/24 network$helpspace Analyst, Master, Heavy, Forward, pfSense,$helpspace Apt-Cacher NG, Web, DC, WEF, Win10$helpspace Mimic an entire network with a single \`vagrant up\`$helpspace IF YOU HAVE THE RESOURCES! NOT FOR THE FAINT OF HEART!"
  whiptail --msgbox --title "Security Onion Help" "$helpmessage" 39 100 9 3>&2 2>&1 1>&3	
  menu
}

menu() {
  DL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  VAGRANT_ONLY=1
  PACKER_ONLY=0
  
  while [ 1 ]
  do
  CHOICE=$(
  whiptail --title "Security Onion Deployment Options" --menu "Make your choice" 16 100 9 \
  	"1." "Minimal Install     - Single Security Onion Instance (Standalone)"   \
  	"2." "Standard Install    - Single Security Onion Instance (Standalone)"  \
  	"3." "Distributed Demo    - Analyst, Master, Heavy, Forward, pfSense, Apt-Cacher NG, Web, DC" \
  	"4." "Windows Lab         - Security Onion (Standalone), pfSense, RTO, DC, WEF, Win10" \
  	"5." "All Machines        - The whole enchilada! Please have at least 64GB of RAM to attempt" \
  	"6." "Halt Options" \
  	"99." "Destroy Options" \
  	"H." "Help" \
  	"Q." "Quit"  3>&2 2>&1 1>&3	
  )
  
  case $CHOICE in
  	"1.")   
      cp $DL_DIR/Vagrant/Vagrantfile_Minimal $DL_DIR/Vagrant/Vagrantfile
      CLI_ARGS=("up")
      CLI_ARGS+=("$@")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"2.")   
      cp $DL_DIR/Vagrant/Vagrantfile_Basic $DL_DIR/Vagrant/Vagrantfile
      CLI_ARGS=("up")
      CLI_ARGS+=("$@")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
    	;;
  
  	"3.")   
      cp $DL_DIR/Vagrant/Vagrantfile_Distributed $DL_DIR/Vagrant/Vagrantfile
      CLI_ARGS=("up")
      CLI_ARGS+=("$@")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
      ;;
  
  	"4.")   
      cp $DL_DIR/Vagrant/Vagrantfile_Lab $DL_DIR/Vagrant/Vagrantfile
      CLI_ARGS=("up")
      CLI_ARGS+=("$@")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
      ;;
  
  	"5.")   
      cp $DL_DIR/Vagrant/Vagrantfile_All $DL_DIR/Vagrant/Vagrantfile
      CLI_ARGS=("up")
      CLI_ARGS+=("$@")
      parse_cli_arguments "${CLI_ARGS[@]}"
  	  main
      cd $DL_DIR
      exit 0
      ;;
  
  	"6.")   
      haltmenu
      ;;
  
  	"99.")   
      destroymenu
      ;;
  
  	"H.")   
      helpmenu
      ;;
  
  	"Q.") exit
          ;;
  esac
  exit
  done
}

menu "$@"
#main "$@"
#exit 0
