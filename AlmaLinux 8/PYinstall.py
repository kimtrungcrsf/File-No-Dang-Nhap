import os
import requests
import re
import subprocess
import shutil
import time
import socket
import resource
import random

def run_cmd(command):
    return subprocess.run(command, shell=True)

def run_cmd_ok(command):
    return subprocess.run(command, shell=True).returncode == 0

def get_os_info():
    info = {}
    try:
        with open("/etc/os-release", "r") as f:
            for line in f:
                if "=" in line:
                    key, value = line.strip().split("=", 1)
                    info[key] = value.strip('"')
    except Exception:
        pass
    return info

def command_exists(command):
    return shutil.which(command) is not None

def init_script_exists(service_name):
    return os.path.exists("/etc/init.d/{}".format(service_name))

def systemctl_unit_exists(unit):
    if not command_exists("systemctl"):
        return False
    result = subprocess.run(
        "systemctl list-unit-files '{}' --no-legend 2>/dev/null | grep -q '{}'".format(unit, unit),
        shell=True
    )
    return result.returncode == 0

def restart_network():
    os_info = get_os_info()
    os_id = os_info.get("ID", "")

    if os_id in ("debian", "ubuntu"):
        run_cmd("sudo /etc/init.d/networking restart")
        return

    if systemctl_unit_exists("NetworkManager.service"):
        run_cmd("systemctl restart NetworkManager")
        return

    if systemctl_unit_exists("network.service"):
        run_cmd("systemctl restart network")
        return

    if command_exists("service") and init_script_exists("network"):
        run_cmd("service network restart")
        return

    print("Khong tim thay dich vu network/NetworkManager de restart")

def stop_firewall():
    if systemctl_unit_exists("firewalld.service"):
        run_cmd("systemctl stop firewalld")

    if systemctl_unit_exists("iptables.service"):
        run_cmd("systemctl stop iptables")
    elif command_exists("service") and init_script_exists("iptables"):
        run_cmd("service iptables stop")

def start_3proxy():
    started = False

    if systemctl_unit_exists("3proxy.service"):
        started = run_cmd_ok("systemctl start 3proxy")
    elif command_exists("service") and init_script_exists("3proxy"):
        started = run_cmd_ok("service 3proxy start")
    elif init_script_exists("3proxy"):
        started = run_cmd_ok("/etc/init.d/3proxy start")

    time.sleep(1)
    if not started or not run_cmd_ok("pgrep -x 3proxy >/dev/null 2>&1"):
        run_cmd("killall 3proxy >/dev/null 2>&1 || true")
        run_cmd("/bin/3proxy /etc/3proxy/3proxy.cfg")
        time.sleep(1)

    run_cmd("pgrep -a 3proxy || true")

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
#IPV4 = get_ipv4()
config = {
    'os_name': get_os_info().get("ID", "linux"),
    'inet6': "eth0"
}

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
        
        ### Khoi Dong Lai networking
        restart_network()
        
        ### Set Proxy
        run_cmd("bash './proxy/boot_ifconfig.sh'")
        run_cmd("killall 3proxy >/dev/null 2>&1 || true")
        shutil.copyfile('./proxy/3proxy.cfg', '/etc/3proxy/3proxy.cfg')
        time.sleep(3)
        
        ### Khoi Dong 3Proxy
        start_3proxy()
    
else:
    
        print("Tien hanh Set Proxy")   
    
        ### Chay Tao File Data Proxy 
        subprocess.run("bash './CreateP.sh'", shell=True)

        ### Khoi Dong Lai networking
        restart_network()
        stop_firewall()
            
        ### Set ulimit 
        set_ulimit()
            
        ### Set Proxy
        run_cmd("bash './proxy/boot_ifconfig.sh'")
        run_cmd("bash './proxy/boot_iptables.sh'")
        run_cmd("killall 3proxy >/dev/null 2>&1 || true")
        shutil.copyfile('./proxy/3proxy.cfg', '/etc/3proxy/3proxy.cfg')
        time.sleep(3)
            
        ### Khoi Dong 3Proxy
        start_3proxy()
        
time.sleep(50)   

### Check IPV6      
CheckIPV6 = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
CheckIPV6 = CheckIPV6.strip().decode('UTF-8')
if CheckIPV6=="200":
  print("Proxy Hoat Dong")
else:
  print("Proxy Khong Hoat Dong")
  subprocess.Popen("python3 /root/PYinstall.py", shell=True)
