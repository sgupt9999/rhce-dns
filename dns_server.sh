#!/bin/bash
############################################################################################
# This script will install DNS server on this machine
############################################################################################
# Start of user inputs
############################################################################################

# End of user inputs
############################################################################################

source ./inputs_dns
rm -rf $LOG_FILE
exec 5>$LOG_FILE

if [[ $EUID != "0" ]]
then
	echo
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "##########################################################"
	echo >&5
	echo "##########################################################" >&5
	echo "ERROR. You need to have root privileges to run this script" >&5
	echo "##########################################################" >&5
	exit 1
fi

yum install wget -y -q
rm -rf common_fn
wget $COMMON_FILE
source ./common_fn

INSTALLPACKAGES="bind bind-utils"

if yum list installed bind >&5 2>&5
then
	systemctl -q is-actuve named && {
	systemctl stop named
	systemctl -q disable named
	}


	MESSAGE="Removing old copy of bind"
	print_msg_start
	yum remove -y -q bind >&5 2>&5
	print_msg_done
fi

MESSAGE="Installing bind"
print_msg_start
yum install -y -q $INSTALLPACKAGES >&5 2>&5
print_msg_done

# Config changes for a caching server
sed -i "s/127.0.0.1;/127.0.0.1;$IPSERVER;/" /etc/named.conf
sed -i "s/localhost;/localhost;$IPCLIENT;/" /etc/named.conf

systemctl enable --now named
