#!/bin/sh
set -e

version="0.9.4"
URL_3PROXY="https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/refs/heads/master/scripts/3proxy-0.9.4.tar.gz"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

detect_os() {
	if [ -r /etc/os-release ]; then
		. /etc/os-release
		OS_ID="$ID"
		OS_VERSION="$VERSION_ID"
	else
		OS_ID="unknown"
		OS_VERSION=""
	fi
}

install_packages() {
	case "$OS_ID" in
		debian|ubuntu)
			apt-get update -y
			DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential gcc make wget curl tar gzip zip psmisc nano python3 python3-pip python3-requests iproute2 iptables ca-certificates
			;;
		almalinux|rocky|rhel|fedora)
			dnf -y update
			dnf -y groupinstall "Development Tools" || true
			dnf -y install gcc make wget curl tar gzip zip psmisc nano python3 python3-pip python3-requests iproute iptables-services ca-certificates
			;;
		centos)
			yum -y update
			yum -y groupinstall "Development Tools" || true
			yum -y install gcc make wget curl tar gzip zip psmisc nano python3 python3-pip python3-requests iproute iptables-services ca-certificates
			;;
		*)
			echo "Khong ho tro OS: $OS_ID $OS_VERSION"
			exit 1
			;;
	esac
}

install_python_packages() {
	python3 -m pip install --upgrade pip || true
	python3 - <<'PY' || python3 -m pip install --break-system-packages requests || python3 -m pip install requests || true
import requests
PY
}

install_3proxy() {
	killall 3proxy >/dev/null 2>&1 || true
	DIR_3PROXY="3proxy-${version}"
	cd /root
	rm -rf "$DIR_3PROXY"

	if [ -f "${SCRIPT_DIR}/3proxy-${version}.tar.gz" ]; then
		tar -xzf "${SCRIPT_DIR}/3proxy-${version}.tar.gz"
	elif [ -f "/root/3proxy-${version}.tar.gz" ]; then
		tar -xzf "/root/3proxy-${version}.tar.gz"
	else
		wget -qO- "$URL_3PROXY" | tar -xzf -
	fi

	cd "$DIR_3PROXY"
	make -f Makefile.Linux
	mkdir -p /etc/3proxy/bin /etc/3proxy/logs /etc/3proxy/stat
	cp bin/3proxy /usr/local/bin/3proxy
	ln -sf /usr/local/bin/3proxy /bin/3proxy

	if [ -f ./scripts/init.d/3proxy.sh ]; then
		cp ./scripts/init.d/3proxy.sh /etc/init.d/3proxy
		chmod +x /etc/init.d/3proxy
	fi

	cat >/etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/usr/bin/killall 3proxy
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	systemctl enable 3proxy || true
	cd /root
}

gen_autoboot() {
	chmod +x /etc/rc.d/rc.local 2>/dev/null || true
	chmod +x /etc/rc.local 2>/dev/null || true
	cat >/etc/rc.local <<EOF
#!/bin/bash
cd /root
python3 /root/PYinstall.py
exit 0
EOF
	chmod +x /etc/rc.local
}

tune_limits() {
	grep -q "root soft nofile 65535" /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<EOF
root soft nproc 65535
root hard nproc 65535
root soft nofile 65535
root hard nofile 65535
EOF
}

check_ipv6() {
	echo "Kiem tra ket noi IPv6 ..."
	if ping6 -c3 bing.com >/dev/null 2>&1; then
		IP4=$(curl -4 -s icanhazip.com || true)
		IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':' || true)
		echo "[OK]: Ket noi IPv6 thanh cong"
		echo "IPV4: $IP4"
		echo "IPV6 prefix: $IP6"
	else
		echo "[CANH BAO]: IPv6 chua ping ra ngoai duoc. Neu ban set IPv6 thu cong thi co the bo qua buoc nay."
	fi
}

download_runtime_files_if_missing() {
	cd /root
	if [ -f "${SCRIPT_DIR}/PYinstall.py" ]; then
		cp "${SCRIPT_DIR}/PYinstall.py" /root/PYinstall.py
	else
		[ -f PYinstall.py ] || wget "https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/master/scripts/PYinstall.py" -O PYinstall.py
	fi

	if [ -f "${SCRIPT_DIR}/CreateP.sh" ]; then
		cp "${SCRIPT_DIR}/CreateP.sh" /root/CreateP.sh
	else
		[ -f CreateP.sh ] || wget "https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/master/scripts/CreateP.sh" -O CreateP.sh
	fi

	if [ -f "${SCRIPT_DIR}/CheckProxy.py" ]; then
		cp "${SCRIPT_DIR}/CheckProxy.py" /root/CheckProxy.py
	else
		[ -f CheckProxy.py ] || wget "https://raw.githubusercontent.com/kimtrungcrsf/File-No-Dang-Nhap/master/scripts/CheckProxy.py" -O CheckProxy.py
	fi
	chmod +x PYinstall.py CreateP.sh CheckProxy.py 2>/dev/null || true
}

if [ "x$(id -u)" != "x0" ]; then
	echo "Error: this script can only be executed by root"
	exit 1
fi

detect_os
echo "Detected OS: $OS_ID $OS_VERSION"
install_packages
check_ipv6
echo "Installing 3proxy"
install_3proxy
echo "Installing rc.local autoboot"
gen_autoboot
tune_limits
install_python_packages
download_runtime_files_if_missing

echo "Setup xong. Hay sua IPV4, prefix, subnet, port, user/pass trong /root/CreateP.sh roi chay: python3 /root/PYinstall.py"
