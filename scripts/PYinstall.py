import os
import requests
import re
import subprocess
import shutil
import time
import socket
import resource
import random

def is_valid_ipv4_address(address):
    address = str(address)
    try:
        socket.inet_pton(socket.AF_INET, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        return address.count('.') == 3
    except socket.error:  # not a valid address
        return False
    return True
    
def is_valid_ipv6_address(address):
    address = str(address)
    try:
        socket.inet_pton(socket.AF_INET6, address)
    except socket.error:  # not a valid address
        return False
    return True

def download_file(filename, url):
    print("Download: {}".format(filename))
    if not os.path.exists("./logs/"): os.makedirs("./logs/")
    try:
        with requests.get(url, stream=True) as r:
            r.raise_for_status()
            with open("logs/{}".format(filename), 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        return True
    except Exception as err:
        print(err)
        return False


#GET IPV4
def get_ipv4():
    try:
        IPV4 = subprocess.Popen("curl -4 -s icanhazip.com", shell=True, stdout=subprocess.PIPE).stdout.read()
        IPV4 = IPV4.strip().decode('UTF-8')
        if not is_valid_ipv4_address(IPV4):
            print("Khong tim thay IPV4")
            exit()
        else:
            print("IPV4: {}".format(IPV4))
            return IPV4
    except Exception as err:
        print(err)
        exit()

#GET IPV6
def get_ipv6():
    try:
        IPV6 = subprocess.Popen("curl -6 -s icanhazip.com", shell=True, stdout=subprocess.PIPE).stdout.read()
        IPV6 = IPV6.strip().decode('UTF-8')
        if not is_valid_ipv6_address(IPV6):
            print("Khong tim thay IPV6")
            exit()
        else:
            print("IPV6: {}".format(IPV6))
            return IPV6
    except Exception as err:
        print(err)
        exit()
   
def set_ulimit():
    ulimit = 0
    while True:
        ulimit = subprocess.Popen("ulimit -Sn", shell=True, stdout=subprocess.PIPE).stdout.read()
        ulimit = ulimit.strip().decode('UTF-8')
        if int(ulimit) == 65535: break
        else: os.system("ulimit -n 65535")
        time.sleep(1)
    return ulimit

##### Cau Hinh Tai Day #####
IPV4 = get_ipv4()
config = {
    'os_name': "centos_7",
    'inet6': "eth0"
}


set_ulimit()

### Tao File Data Proxy 
subprocess.run("bash './CreateP.sh'", shell=True)

### Check trang thai proxy      
CheckProxy = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
CheckProxy = CheckProxy.strip().decode('UTF-8')
if CheckProxy =="200":
  TrangThai_Proxy = "DOI_IP"
else:
  TrangThai_Proxy = "TAO_MOI"
    
### Thuc Hien Set Proxy     
if TrangThai_Proxy =="DOI_IP":

    print("Tien hanh Doi IP Proxy")
    ### Set Proxy
    os.system("service iptables stop")
    os.system("systemctl stop firewalld")
    time.sleep(2)
    subprocess.Popen("bash './proxy/boot_ifconfig.sh'", shell=True)
    subprocess.Popen("killall 3proxy", shell=True)
    shutil.copyfile('./proxy/3proxy.cfg', '/etc/3proxy/3proxy.cfg')
    time.sleep(1)
        
    ### Khoi Dong 3Proxy
    if config['os_name']=="debian":
        subprocess.Popen("sudo /etc/init.d/3proxy start", shell=True)
    elif config['os_name']=="centos_7":
        subprocess.Popen("service 3proxy start", shell=True)
        
else:

    print("Tien hanh Set Proxy")
    
    if config['os_name']=="debian":
        subprocess.Popen("sudo /etc/init.d/networking restart", shell=True)
    elif config['os_name']=="centos_7":
        os.system("service network restart")
        os.system("service iptables stop")
        os.system("systemctl stop firewalld")
        
    time.sleep(3)
        
    ### Set Proxy
    subprocess.Popen("bash './proxy/boot_ifconfig.sh'", shell=True)
    subprocess.Popen("killall 3proxy", shell=True)
    shutil.copyfile('./proxy/3proxy.cfg', '/etc/3proxy/3proxy.cfg')
    time.sleep(1)
        
    ### Khoi Dong 3Proxy
    if config['os_name']=="debian":
        subprocess.Popen("sudo /etc/init.d/3proxy start", shell=True)
    elif config['os_name']=="centos_7":
        subprocess.Popen("service 3proxy start", shell=True)
        
time.sleep(10)   

### Check IPV6      
CheckIPV6 = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
CheckIPV6 = CheckIPV6.strip().decode('UTF-8')
if CheckIPV6=="200":
  print("Proxy Hoat Dong")
else:
  print("Proxy Khong Hoat Dong")
  exec(open('PYinstall.py').read())
