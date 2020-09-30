#!/bin/sh
echo "Changing interface name"
/sbin/ip link set eth0 down
/sbin/ip link set eth0 name eth123
/sbin/ip link set eth123 up
