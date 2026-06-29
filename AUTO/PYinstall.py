import os
import shutil
import socket
import subprocess
import time
import resource


def run_cmd(command, check=False):
    return subprocess.run(command, shell=True, check=check)


def run_cmd_ok(command):
    return subprocess.run(command, shell=True).returncode == 0


def command_exists(command):
    return shutil.which(command) is not None


def init_script_exists(service_name):
    return os.path.exists("/etc/init.d/{}".format(service_name))


def systemctl_unit_exists(unit):
    if not command_exists("systemctl"):
        return False
    return run_cmd_ok("systemctl list-unit-files '{}' --no-legend 2>/dev/null | grep -q '{}'".format(unit, unit))


def start_3proxy():
    started = False

    if systemctl_unit_exists("3proxy.service"):
        started = run_cmd_ok("systemctl restart 3proxy")
    elif command_exists("service") and init_script_exists("3proxy"):
        started = run_cmd_ok("service 3proxy restart")
    elif init_script_exists("3proxy"):
        started = run_cmd_ok("/etc/init.d/3proxy restart")

    time.sleep(1)
    if not started or not run_cmd_ok("pgrep -x 3proxy >/dev/null 2>&1"):
        run_cmd("killall 3proxy >/dev/null 2>&1 || true")
        if os.path.exists("/usr/local/bin/3proxy"):
            run_cmd("/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg")
        elif os.path.exists("/bin/3proxy"):
            run_cmd("/bin/3proxy /etc/3proxy/3proxy.cfg")
        else:
            print("Khong tim thay binary 3proxy")
        time.sleep(1)

    run_cmd("pgrep -a 3proxy || true")


def is_valid_ipv4_address(address):
    try:
        socket.inet_pton(socket.AF_INET, str(address))
        return True
    except socket.error:
        return False


def is_valid_ipv6_address(address):
    try:
        socket.inet_pton(socket.AF_INET6, str(address))
        return True
    except socket.error:
        return False


def set_ulimit():
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    target = 65535
    new_hard = max(hard, target) if hard != resource.RLIM_INFINITY else hard
    try:
        resource.setrlimit(resource.RLIMIT_NOFILE, (target, new_hard))
    except Exception as err:
        print("Khong set duoc ulimit 65535: {}".format(err))


def check_proxy():
    if not os.path.exists("./proxy/checkProxy.sh"):
        return ""
    result = subprocess.Popen("bash './proxy/checkProxy.sh'", shell=True, stdout=subprocess.PIPE).stdout.read()
    return result.strip().decode("UTF-8")


def wait_proxy_ok(timeout=30, interval=3):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if check_proxy() == "200":
            return True
        time.sleep(interval)
    return False


def create_proxy_files():
    run_cmd("bash './CreateP.sh'", check=True)


def apply_proxy_files():
    run_cmd("bash './proxy/boot_ifconfig.sh'")
    run_cmd("bash './proxy/boot_iptables.sh'")
    run_cmd("killall 3proxy >/dev/null 2>&1 || true")
    os.makedirs("/etc/3proxy", exist_ok=True)
    shutil.copyfile("./proxy/3proxy.cfg", "/etc/3proxy/3proxy.cfg")
    time.sleep(2)
    start_3proxy()


os.chdir("/root")
create_proxy_files()

if check_proxy() == "200":
    print("Tien hanh Doi IP Proxy")
else:
    print("Tien hanh Set Proxy")

set_ulimit()
apply_proxy_files()

if wait_proxy_ok():
    print("Proxy Hoat Dong")
else:
    print("Proxy Khong Hoat Dong")
    subprocess.Popen("cd /root && python3 /root/PYinstall.py", shell=True)
