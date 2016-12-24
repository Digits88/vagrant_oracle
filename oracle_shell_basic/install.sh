#!/usr/bin/env bash

## http://blog.whitehorses.nl/2014/03/18/installing-java-oracle-11g-r2-express-edition-and-sql-developer-on-ubuntu-64-bit/


set -o nounset
set -o errexit


# Basic paths
vagrant_home="/home/vagrant"
sync_oracle=/sync/oracle
chkconfig_path=/sbin/chkconfig
oracle60conf_path=/etc/sysctl.d/60-oracle.conf

sudo apt-get update
sudo apt-get install -y unzip
sudo apt-get install -y alien libaio1 unixodbc




## Add chkconfig
if [ ! -e $chkconfig_path ]; then
	sudo cat >> $chkconfig_path << CHKCONFIG
#!/bin/bash
# Oracle 11gR2 XE installer chkconfig hack for Ubuntu
file=/etc/init.d/oracle-xe
if [[ ! \`tail -n1 \$file | grep INIT\` ]]; then
  echo >> \$file
  echo '### BEGIN INIT INFO' >> \$file
  echo '# Provides: OracleXE' >> \$file
  echo '# Required-Start: \$remote_fs \$syslog' >> \$file
  echo '# Required-Stop: \$remote_fs \$syslog' >> \$file
  echo '# Default-Start: 2 3 4 5' >> \$file
  echo '# Default-Stop: 0 1 6' >> \$file
  echo '# Short-Description: Oracle 11g Express Edition' >> \$file
  echo '### END INIT INFO' >> \$file
fi
update-rc.d oracle-xe defaults 80 01
CHKCONFIG

	sudo chmod 755 $chkconfig_path
fi




## Add 60-oracle.conf
if [ ! -e $oracle60conf_path ]; then
	sudo cat > $oracle60conf_path << ORACLE60CONF
# Oracle 11g XE kernel parameters
fs.file-max=6815744
net.ipv4.ip_local_port_range=9000 65000
kernel.sem=250 32000 100 128
kernel.shmmax=536870912
ORACLE60CONF
fi




## Load the kernel parameters:
sudo service procps start




## === Set awk path to oracle
awk_path=/bin/awk
if [ ! -L $awk_path ]; then
  if [ -f $awk_path ]; then
    rm $awk_path
  fi
  sudo ln -s /usr/bin/awk $awk_path
  echo "#=== $awk_path symlink has been created!"
fi
## === Set /var/lock/subsys for oracle
subsys_path=/var/lock/subsys
if [ ! -d $subsys_path ]; then
  sudo mkdir -p $subsys_path
	sudo touch "$subsys_path/listener"
fi




# install oracle DBMS
oracle_zip=$(ls $sync_oracle | grep "zip")
unzip oracle_zip

oracle_rpm=$(ls "$sync_oracle/Disk1" | grep "rpm")
sudo alien --scripts -d "$sync_oracle/Disk1/$oracle_rpm"

oracle_deb=$(ls "$sync_oracle/Disk1" | grep "deb")
sudo dpkg --install "$sync_oracle/Disk1/$oracle_deb"
echo "#=== oracle has been installed!"




## === Set /dev/shm for oracle and mount fs
shm_path=/dev/shm
if [ -d $shm_path ]; then
  sudo rm -rf $shm_path
fi
sudo mkdir $shm_path
sudo mount -t tmpfs shmfs -o size=2048m $shm_path




## Add S01shm_load_path
S01shm_load_path=/etc/rc2.d/S01shm_load
if [ ! -e $S01shm_load_path ]; then
	sudo cat > $S01shm_load_path << S01SHMLOAD
#!/bin/sh
case "\$1" in
start)
  mkdir /var/lock/subsys 2>/dev/null
  touch /var/lock/subsys/listener
  rm /dev/shm 2>/dev/null
  mkdir /dev/shm 2>/dev/null
	mount -t tmpfs shmfs -o size=2048m /dev/shm ;;
*)
  echo error
  exit 1
  ;;
esac
S01SHMLOAD

	sudo chmod 755 $S01shm_load_path
fi




# Setup the environment vars
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




# install and set up rlwrap
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




# Config Oracle
sudo /etc/init.d/oracle-xe configure << CONFIGURE
8080
1521
admin
admin
y
CONFIGURE
echo "#=== configuration has been done!"




## Add vagrant user to the database
dba_username="vagrant"
sudo usermod -a -G dba $dba_username




# start oracle
sudo service oracle-xe start
echo "#=== oracle service is running"



