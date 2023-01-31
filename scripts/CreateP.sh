#!/bin/bash
############ Cau Hinh 
IPV4="102.223.180.86"
IPV6="2a03:94e1:ffff:102:223:180::86"
prefix="2a03:94e1:244f"
subnet=48
port_start=39000
max_ips=200
os_name="centos_7"
inet6="eth0"
TypeProxy="http://"
userProxy="trungle"
PassProxy="123123"

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
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}


############ Tao File ifconfig
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}


############ Tao File 3proxy.cfg
gen_3proxy() {
    cat <<EOF
daemon
maxconn 3000
nserver 1.1.1.1
nserver 1.0.0.1
nserver 2606:4700:4700::1111
nserver 2606:4700:4700::1001
nscache 65536
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
}


############ Tao File Thong tin Proxy
proxy_file() {
    cat <<EOF
$(awk -F "/" '{print "http://" $3 ":" $4 ":" $1 ":" $2}' ${WORKDATA})
EOF
}

############ Tao File check Proxy
proxy_Check() {
    cat <<EOF
curl -I -x http://$userProxy:$PassProxy@$IPV4:$port_start https://whatismyipaddress.com | grep HTTP/1.0 | cut -f2-2 -d' '
EOF
}


############ Tao Folder chua thong tin
echo "working folder = /root/proxy/"
WORKDIR="/root/proxy/"
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
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
gen_3proxy >$WORKDIR/3proxy.cfg
proxy_file >$WORKDIR/proxy.txt
proxy_Check >$WORKDIR/checkProxy.sh
chmod 777 $WORKDIR/boot_iptables.sh
chmod 777 $WORKDIR/boot_ifconfig.sh
chmod 777 $WORKDIR/checkProxy.sh
