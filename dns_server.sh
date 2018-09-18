#!/bin/bash
############################################################################################
# This script will install DNS server on this machine
############################################################################################
# Start of user inputs
############################################################################################

FIREWALL="yes" # Firewalld should be up and running
#FIREWALL="no"

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
else
	echo
	echo "#####################################################"
	echo "This script will install a DNS server on this machine"
	echo "#####################################################"
fi

yum install wget -y -q > /dev/null 2>&1
rm -rf common_fn
wget -q $COMMON_FILE
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
sed -i "s/.*listen-on port 53.*/\tlisten-on port 53 {127.0.0.1;$IPSERVER;};/" /etc/named.conf  #  ips the server is listening on
sed -i "s/.*allow-query.*/\tallow-query {localhost;$IPCLIENT;};/" /etc/named.conf  #  ips the server accepts queries from

systemctl -q enable --now named

# Creating zone files
MESSAGE="Creating zone files"
print_msg_start

FWDFILENAME="fwd.$DOMAIN.db"
# forward lookup zone
sed -i "/include.*rfc1912/i zone \"$DOMAIN\" {" /etc/named.conf   # Insert before the include statement
sed -i "/include.*rfc1912/i  type master;" /etc/named.conf
sed -i "/include.*rfc1912/i  file \"$FWDFILENAME\";" /etc/named.conf
sed -i "/include.*rfc1912/i };"  /etc/named.conf

REVERSEIP=`echo $IPDOMAIN | awk -F . '{print $3"."$2"."$1}'`
REVERSEFILENAME="$REVERSEIP.db"
# reverse lookup zone
sed -i "/include.*rfc1912/i zone \"$REVERSEIP.in-addr.arpa\" {" /etc/named.conf
sed -i "/include.*rfc1912/i	type master;" /etc/named.conf
sed -i "/include.*rfc1912/i	file \"$REVERSEFILENAME\";" /etc/named.conf
sed -i "/include.*rfc1912/i };"  /etc/named.conf

# Create zone files
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
echo "$HOST	IN	A	$IPDOMAIN" >> /var/named/$FWDFILENAME

REVERSEIP=`echo $IPDOMAIN | awk -F . '{print $4}'`
rm -rf /var/named/$REVERSEFILENAME
echo "\$TTL 86400" >> /var/named/$REVERSEFILENAME
echo "@		IN SOA $FQDN. root.$DOMAIN. (" >> /var/named/$REVERSEFILENAME
echo "			10030	;Serial" >> /var/named/$REVERSEFILENAME
echo "			3600	;Refresh" >> /var/named/$REVERSEFILENAME
echo "			1800	;Retry" >> /var/named/$REVERSEFILENAME
echo "			604800	;Expire" >>/var/named/$REVERSEFILENAME
echo "			86400	;Minimum TTL" >> /var/named/$REVERSEFILENAME
echo ")" >> /var/named/$REVERSEFILENAME
echo "; Name Server" >> /var/named/$REVERSEFILENAME
echo "@		IN 	NS	$FQDN." >> /var/named/$REVERSEFILENAME
echo "; Pointer Records" >> /var/named/$REVERSEFILENAME
echo "$REVERSEIP	IN	PTR	$FQDN." >> /var/named/$REVERSEFILENAME

print_msg_done


if [[ $FIREWALL == "yes" ]]
then
	if systemctl -q is-active firewalld
	then
		MESSAGE="Adding DNS to firewall"
		print_msg_start
		firewall-cmd -q --permanent --add-service dns
		firewall-cmd -q --reload
		print_msg_done
	else
		MESSAGE="Firewalld not running. No changes made to firewall"
		print_msg_header
	fi
fi


systemctl restart named
MESSAGE="DNS Server created. Zone files created for $FQDN and $IPDOMAIN"
print_msg_header
