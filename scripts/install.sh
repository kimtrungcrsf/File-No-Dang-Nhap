#! / bin / sh
ngẫu nhiên () {
	tr < / dev / urandom -dc A-Za-z0-9 | đầu -c5
	tiếng vang
}

mảng = (1 2 3 4 5 6 7 8 9 0 abcdef)
gen64 () {
	ip64 () {
		echo  " $ {array [$ RANDOM% 16]} $ {array [$ RANDOM% 16]} $ {array [$ RANDOM% 16]} $ {array [$ RANDOM% 16]} "
	}
	echo  " $ 1 : $ ( ip64 ) : $ ( ip64 ) : $ ( ip64 ) : $ ( ip64 ) "
}
install_3proxy () {
    echo  " cài đặt 3proxy "
    URL = " https://raw.githubusercontent.com/kimtrungcrsf/3proxy/master/3proxy-3proxy-0.8.6.tar.gz "
    wget -qO- $ URL  | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p / usr / local / etc / 3proxy / {bin, logs, stat}
    cp src / 3proxy / usr / local / etc / 3proxy / bin /
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod + x /etc/init.d/3proxy
    chkconfig 3proxy trên
    cd  $ WORKDIR
}

gen_3proxy () {
    con mèo << EOF
daemon
maxconn 1000
nscache 65536
hết thời gian chờ 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
tuôn ra
auth mạnh
người dùng $ (awk -F "/" 'BEGIN {ORS = "";} {print $ 1 ": CL:" $ 2 ""}' $ {WORKDATA})
$ (awk -F "/" '{print "auth iponly \ n" \
"#allow" $ 1 "\ n" \
"proxy -6 -n -a -p" $ 4 "-i" $ 3 "-e" $ 5 "\ n" \
"tuôn ra \ n"} '$ {WORKDATA})
EOF
}

gen_proxy_file_for_user () {
    cat > proxy.txt << EOF
$ (awk -F "/" '{print $ 3 ":" $ 4}' $ {WORKDATA})
EOF
}

gen_data () {
    seq $ FIRST_PORT  $ LAST_PORT  |  cổng trong khi  đọc ;  làm
        echo  " usr $ ( random ) / pass $ ( random ) / $ IP4 / $ port / $ ( gen64 $ IP6 ) "
    làm xong
}

gen_iptables () {
    con mèo << EOF
    $ (awk -F "/" '{print "iptables -I INPUT -p tcp --dport" $ 4 "-m state --state NEW -j ACCEPT"}' $ {WORKDATA}) 
EOF
}

gen_ifconfig () {
    con mèo << EOF
$ (awk -F "/" '{print "ifconfig eth0 inet6 thêm" $ 5 "/ 64"}' $ {WORKDATA})
EOF
}
echo  " cài đặt ứng dụng "
yum -y cài đặt gcc net-tools bsdtar zip > / dev / null

install_3proxy

echo  " thư mục làm việc = / home / proxy-installer "
WORKDIR = " / home / proxy-installer "
WORKDATA = " $ {WORKDIR} /data.txt "
mkdir $ WORKDIR  &&  cd  $ _

IP4 = $ ( curl -4 -s icanhazip.com )
IP6 = $ ( curl -6 -s icanhazip.com | cut -f1-4 -d ' : ' )

echo  " Internal ip = $ {IP4} . Exteranl sub cho ip6 = $ {IP6} "

echo  " Bạn muốn tạo bao nhiêu proxy? Ví dụ 500 "
đọc COUNT

FIRST_PORT = 50000
LAST_PORT = $ (( $ FIRST_PORT  +  $ COUNT ))

gen_data > $ WORKDIR /data.txt
gen_iptables > $ WORKDIR /boot_iptables.sh
gen_ifconfig > $ WORKDIR /boot_ifconfig.sh
chmod + x boot_ * .sh /etc/rc.local

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

mèo >> /etc/rc.local << EOF
bash $ {WORKDIR} /boot_iptables.sh
bash $ {WORKDIR} /boot_ifconfig.sh
ulimit -n 10048
dịch vụ 3 proxy bắt đầu
EOF

bash /etc/rc.local

gen_proxy_file_for_user
