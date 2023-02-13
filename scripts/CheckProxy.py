import os
import requests
import re
import subprocess
import shutil
import time
import socket
import resource
import random

def set_ulimit():
    ulimit = 0
    while True:
        ulimit = subprocess.Popen("ulimit -Sn", shell=True, stdout=subprocess.PIPE).stdout.read()
        ulimit = ulimit.strip().decode('UTF-8')
        if int(ulimit) == 65535: break
        else: os.system("ulimit -n 65535")
        time.sleep(1)
    return ulimit

### Check trang thai proxy      
CheckProxy = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
CheckProxy = CheckProxy.strip().decode('UTF-8')
if CheckProxy =="200":
  TrangThai_Proxy = "Proxy Hoat Dong"
else:
  TrangThai_Proxy = "Proxy Khong Hoat Dong"
    
### Thuc Hien khoi dong 3proxy Proxy     
if TrangThai_Proxy =="Proxy Khong Hoat Dong":
    
        print("Khoi Dong lai 3proxy")
        
        ### Khoi Dong Lai networking
        if config['os_name']=="debian":
            subprocess.Popen("sudo /etc/init.d/networking restart", shell=True)
        elif config['os_name']=="centos_7":
            os.system("service network restart")
            os.system("service iptables stop")
            os.system("systemctl stop firewalld")
            subprocess.Popen("killall 3proxy", shell=True)
        
        time.sleep(3)
        
        ### Set ulimit 
        set_ulimit()
        
        ### Khoi Dong 3Proxy
        if config['os_name']=="debian":
            subprocess.Popen("sudo /etc/init.d/3proxy start", shell=True)
        elif config['os_name']=="centos_7":
            subprocess.Popen("service 3proxy start", shell=True)  
        
time.sleep(30)   

### Check trang thai proxy  lan 2    
CheckIPV6 = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
CheckIPV6 = CheckIPV6.strip().decode('UTF-8')
if CheckIPV6=="200":
  print("Proxy Hoat Dong")
else:
  print("Proxy Khong Hoat Dong")
  subprocess.Popen("python3 /root/CheckProxy.py", shell=True)