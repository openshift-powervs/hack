#!/bin/bash -x
### private - env9
### public - env2
#PRIVATE_INT="env9"
#PUBLIC_INT="env2"
GATEWAY_IP="192.168.150.1"

echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -A FORWARD -i env9 -o env2 -j ACCEPT
iptables -A FORWARD -i env2 -o env9 -m state --state ESTABLISHED,RELATED \
         -j ACCEPT
iptables -t nat -A POSTROUTING -o env2 -j MASQUERADE

iptables -A FORWARD -i env9 -j ACCEPT
iptables -A FORWARD -o env9 -j ACCEPT

ethtool --offload env9 rx off tx off
ethtool -K env2 tso off
ethtool -K env9 tso off
ethtool -K env9 gso off

ip route add 10.241.64.0/24 via $GATEWAY_IP dev env9
ip route add 10.242.0.0/24 via $GATEWAY_IP dev env9
ip route add 10.242.64.0/24 via $GATEWAY_IP dev env9
ip route add 10.242.128.0/24 via $GATEWAY_IP dev env9
