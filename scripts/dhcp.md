Instructions for dhcp server for powervs static network:

Create a vm with both public and private network(select .2 as ip address so that we can same for the gateway as well

Download the pvsadm from https://github.com/ppc64le-cloud/pvsadm/releases/tag/v0.1.3 into /usr/loca/bin path

```
$ cat /etc/systemd/system/dhcpd-sync.service
[Unit]
Description=Service that keeps running the dhcpd-sync service running on the system
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
ExecStart=/bin/bash /usr/local/bin/script.sh
WorkingDirectory=/tmp
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=%n
```

```
$ cat /usr/local/bin/script.sh
#!/usr/bin/env bash

export IBMCLOUD_API_KEY=<insert_valid_api_key>
# update the information properly in the following line like instance-id, network-id, gateway(here the dhcp server is also acting like snat gateway) which is usually a .2 ip address in that private network
pvsadm dhcp-sync --instance-id e449d86e-c3a0-4c07-959e-8557fdf55482 --network-id daf2b616-542b-47ed-8cec-ceaec1e90f4d --gateway 192.168.151.2 --nameservers 8.8.8.8,8.8.4.4
```

**SNAT instructions:**

```
# cat ip-forward.sh
#!/bin/bash -x
### private - env3
### public - env2
#PRIVATE_INT="env3"
#PUBLIC_INT="env2"

echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -A FORWARD -i env3 -o env2 -j ACCEPT
iptables -A FORWARD -i env2 -o env3 -m state --state ESTABLISHED,RELATED \
         -j ACCEPT
iptables -t nat -A POSTROUTING -o env2 -j MASQUERADE

iptables -A FORWARD -i env3 -j ACCEPT
iptables -A FORWARD -o env3 -j ACCEPT

ethtool --offload env3 rx off tx off
ethtool -K env3 tso off
ethtool -K env3 gso off

ip route add 10.242.64.0/24 via 192.168.151.1 dev env3
```
