#!/bin/bash
############ Cau Hinh 
IPV4="auto"
prefix="auto"
subnet="auto"
port_start=39000
max_ips=350
ProxyAuth="YES"
TypeProxy="http://"
userProxy="trungle"
PassProxy="123123"
os_name="unknown"
inet6="auto"

if [ -r /etc/os-release ]; then
    . /etc/os-release
    os_name="$ID"
fi

detect_interface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
}

detect_ipv4() {
    local public_ip route_ip
    public_ip=$(curl -4 -s --max-time 10 icanhazip.com 2>/dev/null | tr -d '[:space:]')
    if echo "$public_ip" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
    then
        echo "$public_ip"
        return
    fi

    route_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')
    echo "$route_ip"
}

detect_ipv6_cidr() {
    local dev="$1"
    ip -6 addr show dev "$dev" scope global 2>/dev/null | \
        awk '/inet6/ && $2 !~ /^fe80:/ {print $2; exit}'
}

detect_prefix_from_cidr() {
    local cidr="$1"
    python3 - "$cidr" <<'PY'
import ipaddress
import sys

cidr = sys.argv[1]
iface = ipaddress.IPv6Interface(cidr)
length = iface.network.prefixlen

if length <= 48:
    prefix_len = 48
elif length <= 64:
    prefix_len = 64
else:
    prefix_len = 64

network = ipaddress.IPv6Network((iface.ip, prefix_len), strict=False)
groups = network.network_address.exploded.split(":")
print(":".join(groups[:prefix_len // 16]))
PY
}

detect_subnet_from_cidr() {
    local cidr="$1"
    local length
    length=$(echo "$cidr" | awk -F "/" '{print $2}')

    if [ "$length" -le 48 ] 2>/dev/null
    then
        echo 48
    else
        echo 64
    fi
}

if [ "$inet6" = "auto" ] || [ -z "$inet6" ]; then
    inet6=$(detect_interface)
fi

if [ "$IPV4" = "auto" ] || [ -z "$IPV4" ]; then
    IPV4=$(detect_ipv4)
fi

IPV6_CIDR=$(detect_ipv6_cidr "$inet6")

if [ "$prefix" = "auto" ] || [ -z "$prefix" ]; then
    if [ -n "$IPV6_CIDR" ]; then
        prefix=$(detect_prefix_from_cidr "$IPV6_CIDR")
    else
        echo "Khong tu nhan duoc IPv6 prefix tren interface $inet6"
        exit 1
    fi
fi

if [ "$subnet" = "auto" ] || [ -z "$subnet" ]; then
    if [ -n "$IPV6_CIDR" ]; then
        subnet=$(detect_subnet_from_cidr "$IPV6_CIDR")
    else
        subnet=64
    fi
fi

echo "OS: $os_name"
echo "Interface: $inet6"
echo "IPV4: $IPV4"
echo "IPv6 CIDR: ${IPV6_CIDR:-not_found}"
echo "IPv6 prefix: $prefix"
echo "IPv6 subnet: /$subnet"


############ Tao Thong tin Port
FIRST_PORT=$port_start
LAST_PORT=$(($FIRST_PORT + ($max_ips - 1)))


############ Random
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

############ Random Data Subnet 64 bit
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$prefix:$(ip64):$(ip64):$(ip64):$(ip64)"
}
gen_data64() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$userProxy/$PassProxy/$IPV4/$port/$(gen64 $IPV6)"
    done
}

############ Random Data Subnet 48 bit
gen48() {
	ip48() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$prefix:$(ip48):$(ip48):$(ip48):$(ip48):$(ip48)"
}
gen_data48() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$userProxy/$PassProxy/$IPV4/$port/$(gen48 $IPV6)"
    done
}

############ Tao File iptables
gen_iptables() {
    cat <<EOF
#!/bin/sh
FIRST_PORT=$FIRST_PORT
LAST_PORT=$LAST_PORT

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null
then
    firewall-cmd --add-port=\${FIRST_PORT}-\${LAST_PORT}/tcp --permanent >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
fi

if command -v iptables >/dev/null 2>&1
then
    iptables -C INPUT -p tcp --dport \${FIRST_PORT}:\${LAST_PORT} -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport \${FIRST_PORT}:\${LAST_PORT} -j ACCEPT 2>/dev/null || true
fi
EOF
}

############ Tao File add IPv6
gen_ifconfig() {
    cat <<EOF
#!/bin/sh
DEV="$inet6"
WORKDATA="$WORKDATA"
IP_BATCH="/tmp/proxy_ipv6_add.batch"

if ! ip link show "\$DEV" >/dev/null 2>&1
then
    echo "Khong tim thay interface: \$DEV"
    exit 1
fi

awk -F "/" -v dev="\$DEV" '{print "addr add " \$5 "/64 dev " dev}' "\$WORKDATA" > "\$IP_BATCH"
ip -force -6 -batch "\$IP_BATCH" >/dev/null 2>&1 || true
rm -f "\$IP_BATCH"
EOF
}


############ Tao File 3proxy.cfg
gen_3proxy() {
if [ $ProxyAuth == YES ]
then
cat <<EOF
daemon
maxconn 3000
nserver 9.9.9.9
nserver 149.112.112.112
nscache 65536
nscache6 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush
    
users $userProxy:CL:$PassProxy
auth strong cache
allow $userProxy   
$(awk -F "/" '{print "proxy -6 -n -a -p" $4 " -i" $3 " -e" $5 ""}' ${WORKDATA})
flush
EOF
else
cat <<EOF
daemon
maxconn 3000
nserver 9.9.9.9
nserver 149.112.112.112
nscache 65536
nscache6 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush

$(awk -F "/" '{print "proxy -6 -n -a -p" $4 " -i" $3 " -e" $5 ""}' ${WORKDATA})
flush
EOF
fi
}


############ Tao File Thong tin Proxy
proxy_file() {
if [ $ProxyAuth == YES ]
then
cat <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2}' ${WORKDATA})
EOF
else
cat <<EOF
$(awk -F "/" '{print $3 ":" $4}' ${WORKDATA})
EOF
fi 
}

############ Tao File check Proxy
proxy_Check() {
if [ $ProxyAuth == YES ]
then
cat <<EOF
curl -sS --max-time 15 -o /dev/null -w '%{http_code}' -x http://$userProxy:$PassProxy@$IPV4:$LAST_PORT https://api64.ipify.org
EOF
else
cat <<EOF
curl -sS --max-time 15 -o /dev/null -w '%{http_code}' -x http://$IPV4:$LAST_PORT https://api64.ipify.org
EOF
fi 
}


############ Tao Folder chua thong tin
WORKDIR="/root/proxy"
WORKDATA="${WORKDIR}/data.txt"
rm -rf $WORKDIR
mkdir $WORKDIR && cd $_


############ Tao File Data Setup Proxy 
if [ $subnet == 64 ]
then
  gen_data64 >$WORKDIR/data.txt
fi 


if [ $subnet == 48 ]
then
  gen_data48 >$WORKDIR/data.txt
fi 

gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
gen_3proxy >$WORKDIR/3proxy.cfg
proxy_file >$WORKDIR/proxy.txt
proxy_Check >$WORKDIR/checkProxy.sh
chmod 755 $WORKDIR/boot_iptables.sh
chmod 755 $WORKDIR/boot_ifconfig.sh
chmod 755 $WORKDIR/checkProxy.sh
