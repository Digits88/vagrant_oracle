#!/usr/bin/env bash

## http://blog.whitehorses.nl/2014/03/18/installing-java-oracle-11g-r2-express-edition-and-sql-developer-on-ubuntu-64-bit/ ##

set -o nounset
set -o errexit


# Basic paths
vagrant_home="/home/vagrant"
sync_oracle=/sync/oracle
sync_files=/sync/files

install_packages() {
  sudo apt-get update
  sudo apt-get install -y --force-yes unzip
  sudo apt-get install -y --force-yes alien libaio1 unixodbc
}


## Add chkconfig
add_chkconfig() {
  local chkconfig_path=/sbin/chkconfig
  if [ ! -e $chkconfig_path ]; then
    sudo cp -i "$sync_files/chkconfig" $chkconfig_path
    sudo chmod 755 $chkconfig_path
  fi
}



## Add 60-oracle.conf
add_60oracle_conf() {
  local oracle60conf_path=/etc/sysctl.d/60-oracle.conf
  if [ ! -e $oracle60conf_path ]; then
    sudo cp -i "$sync_files/60-oracle.conf" $oracle60conf_path
  fi
}



## Load the kernel parameters:
service_procps_start() {
  sudo service procps start
}




## === Set awk path to oracle
add_awk_link() {
  local awk_path=/bin/awk
  if [ ! -L $awk_path ]; then
    if [ -f $awk_path ]; then
      rm $awk_path
    fi
    sudo ln -s /usr/bin/awk $awk_path
  fi
}

add_subsys() {
  local subsys_path=/var/lock/subsys
  if [ ! -d $subsys_path ]; then
    sudo mkdir -p $subsys_path
    sudo touch "$subsys_path/listener"
  fi
}

unzip_oracle() {
  local oracle_zip=$( find "$sync_oracle" -maxdepth 1 -name "*.zip" )
  unzip "$oracle_zip" -d "$vagrant_home"
  echo "#=== oracle has been unzipped!"
}

convert_rpm_to_deb() {
	local oracle_rpm_path=$( find "$vagrant_home/Disk1" -maxdepth 1 -type f -name "*.rpm" -print0 )
	echo "#=== starting -------------------"
	sudo alien --scripts -d "$oracle_rpm_path"
	echo "#=== finished -------------------"
}


# install oracle DBMS
install_oracle_pkg() {
  # local oracle_deb_path=$( find "$vagrant_home" -maxdepth 1 -type f -name "*.deb" -print0 )
  local oracle_deb_path=$( find "$vagrant_home" -maxdepth 1 -type f -name "*.deb" -print0 )
  sudo dpkg --install "$oracle_deb_path"
  echo "#=== oracle has been installed!"
}



## === Set /dev/shm for oracle and mount fs
mount_fs() {
  shm_path=/dev/shm
  if [ -d $shm_path ]; then
    sudo rm -rf $shm_path
  fi
  sudo mkdir $shm_path
  sudo mount -t tmpfs shmfs -o size=2048m $shm_path
}



## Add S01shm_load_path
add_S01shm_load() {
  local S01shm_load_path=/etc/rc2.d/S01shm_load
  if [ ! -e $S01shm_load_path ]; then
    sudo cp -i "$sync_files/S01shm_load" $S01shm_load_path
    sudo chmod 755 $S01shm_load_path
  fi
}



# Setup the environment vars
set_envvars() {
if ! grep -q ORACLE_HOME "$vagrant_home/.profile"; then
  echo "#=== Setting up ORACLE envvars"
  sudo cat >> "$vagrant_home/.profile"<< ORAVARS

# for oracle
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID=XE
export NLS_LANG=\`\$ORACLE_HOME/bin/nls_lang.sh\`
export ORACLE_BASE=/u01/app/oracle
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export PATH=\$ORACLE_HOME/bin:\$PATH
ORAVARS

	if ! grep -q "/u01/app/oracle/product/11.2.0/xe" "$vagrant_home/.profile"; then
		echo "#=== Oracle envvars has not been set!"
	fi
else
  echo "#=== Oracle envvars are already added to .bashrc"
fi
}



# install and set up rlwrap
install_rlwrap() {
  wget -q "http://ge.archive.ubuntu.com/ubuntu/pool/universe/r/rlwrap/rlwrap_0.37-2_amd64.deb" -P .

  rlwrap_deb=$(ls $vagrant_home | grep rlwrap | tail -n1)
  sudo dpkg --install $rlwrap_deb

  cp "$sync_oracle/.oracle_keywords" $vagrant_home/
  sudo chown vagrant:vagrant $vagrant_home/.oracle_keywords
  alias sqlplus='/usr/bin/rlwrap -if $HOME/.oracle_keywords $ORACLE_HOME/bin/sqlplus'

  if ! grep -q "alias sqlplus" $vagrant_home/.bashrc; then
    sudo cat >> "$vagrant_home/.bashrc" << SQLPLUS

# for sqlplus
alias sqlplus='/usr/bin/rlwrap \-if \$HOME/.oracle_keywords \$ORACLE_HOME/bin/sqlplus'
SQLPLUS
  fi
  echo "#=== rlwrap has been installed and set"
}



# Config Oracle
run_oracle_config() {
  sudo /etc/init.d/oracle-xe configure responseFile="$sync_oracle/response/xe.rsp"
  if [[ "$?" -eq 0 ]]; then
  	echo "#=== configuration has been done!" >&2
  else
    echo "#=== configuration went bad!"
  fi
}



## Add vagrant user to the database
add_vagrant_user_to_db() {
  dba_username="vagrant"
  sudo usermod -a -G dba $dba_username
}



# start oracle
start_service_oracle() {
  sudo service oracle-xe start
  echo "#=== oracle service is running"
}



install_packages
add_chkconfig
add_60oracle_conf
service_procps_start
add_awk_link
add_subsys
unzip_oracle
convert_rpm_to_deb
install_oracle_pkg
mount_fs
add_S01shm_load
set_envvars
install_rlwrap
run_oracle_config
add_vagrant_user_to_db
start_service_oracle

