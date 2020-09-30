#!/bin/sh
echo "Changing interface name"
/sbin/ip link set eth0 down
/sbin/ip link set lo up