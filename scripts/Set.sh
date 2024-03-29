#!/bin/sh
version="0.9.4"
install_3proxy() {
	killall 3proxy
	URL="https://github.com/3proxy/3proxy/archive/refs/tags/${version}.tar.gz"
	DIR_3PROXY="3proxy-${version}"
	wget -qO- $URL | bsdtar -xvf-
	cd $DIR_3PROXY
	make -f Makefile.Linux
	mkdir -p /etc/3proxy/{bin,logs,stat}
	cp bin/3proxy /bin/
    cp ./scripts/init.d/3proxy.sh /etc/init.d/3proxy
	chmod +x /etc/init.d/3proxy
	chkconfig 3proxy on
	cd /root/
}

gen_autoboot() {
	chmod +x /etc/rc.local
	cat >/etc/rc.local <<EOF
#!/bin/bash
python3 /root/PYinstall.py
exit 0
EOF
}

if [ "x$(id -u)" != 'x0' ]; then
    echo 'Error: this script can only be executed by root'
    exit 1
fi

#
yum -y update
yum -y groupinstall "Development Tools"
yum -y install net-tools psmisc gcc zlib-devel openssl-devel readline-devel ncurses-devel wget tar zip dnsmasq net-tools iptables-services system-config-firewall-tui nano iptables-services bsdtar
	
#
echo "Installing apps"
echo "installing 3proxy"
install_3proxy

echo "installing rc_local"
gen_autoboot

echo "root soft nproc 65535" >> /etc/security/limits.conf
echo "root hard nproc 65535" >> /etc/security/limits.conf
echo "root soft nofile 65535" >> /etc/security/limits.conf
echo "root hard nofile 65535" >> /etc/security/limits.conf

systemctl disable --now firewalld
service iptables stop

yum install python3 -y
pip3 install requests

wget "https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/master/scripts/PYinstall.py" -O PYinstall.py
wget "https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/master/scripts/CreateP.sh" -O CreateP.sh
chmod +x PYinstall.py
chmod +x CreateP.sh

