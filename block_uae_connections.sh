#!/bin/bash

# Block UAE connections

# Get the list of UAE IP addresses from ipdeny.com
IP_LIST=$(curl -s https://www.ipdeny.com/ipblocks/data/aggregated/ae-aggregated.zone)

# Loop through each IP address and block it
for ip in $IP_LIST; do
    iptables -A INPUT -s "$ip" -j DROP
done

echo "Blocked UAE connections."