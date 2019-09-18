#!/bin/bash

NFT="/usr/sbin/nft"
LOCAL_INT="" #Internal int name 
EXT_INT="" #External int name 
LOCAL_NET="" #Internal network's ip address like x.x.x.x/netmask
EXT_IP="" #External int ip address
LOCAL_IP="" #Internal int ip address
WEBSRV_IP="" #Web server's ip address
ADMIN_IPS="" #List admin's ip from the internet like x.x.x.x, x.x.x.x

case "$1" in
    start)
        echo "Starting nftables"

	# Enabling Forwarding
	sysctl net.ipv4.ip_forward=1

        # Flushing old ruleset
        $NFT flush ruleset

	# Creating tables
	$NFT add table ip filter
	$NFT add table mynat

	# Creating chains for filter table with default policy
	$NFT add chain ip filter INPUT { type filter hook input priority 0 \; policy drop \; }
	$NFT add chain ip filter FORWARD { type filter hook forward priority 0 \; policy drop \; }
	$NFT add chain ip filter OUTPUT { type filter hook output priority 0 \; policy drop \; }

	# Creating chains for nat table
        $NFT add chain mynat prerouting { type nat hook prerouting priority 0 \; } 
        $NFT add chain mynat postrouting { type nat hook postrouting priority 0 \; } 

	# Adding dnat rule to publish the web server to the internet
        $NFT add rule mynat prerouting iifname $EXT_INT tcp dport {80, 443} dnat $WEBSRV_IP
        $NFT add rule filter FORWARD iifname $EXT_INT tcp dport {80, 443} ip daddr $WEBSRV_IP oifname $LOCAL_INT ct state { new } counter accept 

	# Adding snat and forward rules to opening full internet acsess to local net
        $NFT add rule mynat postrouting ip saddr $LOCAL_NET oifname $EXT_INT snat $EXT_IP
        $NFT add rule filter FORWARD iifname $EXT_INT oifname $LOCAL_INT ip daddr $LOCAL_NET ct state { established, related } counter accept 
        $NFT add rule filter FORWARD iifname $LOCAL_INT oifname $EXT_INT ip saddr $LOCAL_NET ct state { new, established, related } counter accept 

	# Dropping invalid packets
        $NFT add rule filter INPUT ct state { invalid } counter drop
        $NFT add rule filter FORWARD ct state { invalid } counter drop
        $NFT add rule filter OUTPUT ct state { invalid } counter drop

	# Dropping all packets from the internet with privite net sources
	$NFT add rule filter INPUT iifname $EXT_INT ip saddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } counter drop
	$NFT add rule filter FORWARD iifname $EXT_INT ip saddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } counter drop

	# It permits all localhost traffic
        $NFT add rule filter INPUT iifname != lo ip daddr 128.0.0.0/8 reject
        $NFT add rule filter INPUT iifname lo accept
        $NFT add rule filter OUTPUT iifname lo accept

	# It permits all reverse traffic from the internet for the localhost
	$NFT add rule filter INPUT iifname $EXT_INT ct state { established,related } accept

	# It permits all output localhost traffic
	$NFT add rule filter OUTPUT ct state { new,established,related } counter accept

        # It permits an access to the localhost from the internet for the support team 
	$NFT add rule filter INPUT iifname $EXT_INT ip saddr { $ADMIN_IPS } tcp dport 22 ct state new accept

        # It permits all traffic to localhost from localnet
	$NFT add rule filter INPUT iifname $LOCAL_INT ip daddr $LOCAL_IP ct state { new, established, related } counter accept
        ;;

    stop)
        echo "Stopping nftables"
        $NFT flush ruleset

	# Disabling forwarding
	sysctl net.ipv4.ip_forward=0
	;;

    list)
        echo "Listing nftables"
        $NFT list ruleset
	;;

    save)
        echo "Saving active rules to startup - /etc/nftables.conf"
        echo '#!/usr/sbin/nft -f' > /etc/nftables.conf
        echo 'flush ruleset' >> /etc/nftables.conf
        $NFT -s list ruleset >> /etc/nftables.conf
        echo "Don't forget to execute 'systemctl enable nftables'"

	;;
	
    *)
	echo "Usage: $0 {start(to activate the ruleset)|stop(to deactivate the ruleset)|save active rules(to startup - /etc/nftables.conf)}" 
	exit 1
	;;
esac
