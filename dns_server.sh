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
	systemctl -q is-active named && {
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

FWDFILENAME="fwd.$DOMAIN.db"
# forward lookup zone
sed -i "/include.*rfc1912/i zone \"$DOMAIN\" {" /etc/named.conf
sed -i "/include.*rfc1912/i  type master;" /etc/named.conf
sed -i "/include.*rfc1912/i  file \"$FWDFILENAME\";" /etc/named.conf
sed -i "/include.*rfc1912/i };"  /etc/named.conf

REVERSEIP=`echo $IPSERVER | awk -F . '{print $3"."$2"."$1}'`
REVERSEFILENAME="$REVERSEIP.db"
# reverse lookup zone
sed -i "/include.*rfc1912/i zone \"$REVERSEIP.in-addr.arpa\" {" /etc/named.conf
sed -i "/include.*rfc1912/i	type master;" /etc/named.conf
sed -i "/include.*rfc1912/i	file \"$REVERSEFILENAME\";" /etc/named.conf
sed -i "/include.*rfc1912/i };"  /etc/named.conf

rm -rf /var/named/$FWDFILENAME
echo "\$TTL 86400" >> /var/named/$FWDFILENAME
echo "@		IN SOA $FQDN. root.$DOMAIN. (" >> /var/named/$FWDFILENAME
echo "			10030	;Serial" >> /var/named/$FWDFILENAME
echo "			3600	;Refresh" >> /var/named/$FWDFILENAME
echo "			1800	;Retry" >> /var/named/$FWDFILENAME
echo "			604800	;Expire" >>/var/named/$FWDFILENAME
echo "			86400	;Minimum TTL" >> /var/named/$FWDFILENAME
echo ")" >> /var/named/$FWDFILENAME
echo "; Name Server" >> /var/named/$FWDFILENAME
echo "@		IN 	NS	$FQDN." >> /var/named/$FWDFILENAME
echo "; A Record Definitions" >> /var/named/$FWDFILENAME
echo "named	IN	A	$IPDOMAIN" >> /var/named/$FWDFILENAME
