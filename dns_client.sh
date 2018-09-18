#!/bin/bash
######################################################################################################################################
# This script will make a persistent change in /etc/resolv.conf to call the new dns server, which otherwise gets overwritten on reboot
######################################################################################################################################

source ./inputs_dns
rm -rf $LOG_FILE
exec 5>>$LOG_FILE

if [[ $EUID != "0" ]]
then

	echo
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "##########################################################"
	exit 1
else
	echo
	echo "########################################################################################"
	echo "This script will make a persistent change to /etc/resolv.conf to call the new nameserver"
	echo "########################################################################################"
fi

yum install wget -y -q > /dev/null 2>&1
rm -rf common_fn
wget -q $COMMON_FILE
source ./common_fn

INSTALLPACKAGES="bind-utils"

MESSAGE="Installing bind-utils"
print_msg_start
yum install -y -q $INSTALLPACKAGES >/dev/null 2>&1
print_msg_done

# Make the change for the current session
MESSAGE="Making a change to call the new DNS server"
print_msg_start
sed -i "s/.*nameserver/#&/" /etc/resolv.conf
echo "nameserver $IPSERVER" >> /etc/resolv.conf
print_msg_done
sleep 5

MESSAGE="Quering the new records"
print_msg_start
dig $FQDN A +noall +answer
dig -x $IPDOMAIN PTR +noall +answer
print_msg_done

# Add the permanent change to config file
# There is a 2nd method which doesnt work on all AWS EC2
# Add PEERDNS=no and DNS1=NewServerIP ont two separate lines to the ifcfg file in /etc/sysconfig/network-scripts
MESSAGE="Making a persistent change to call the new DNS server"
print_msg_start
echo "supersede domain-name-servers $IPSERVER;" >> /etc/dhcp/dhclient.conf
print_msg_done

