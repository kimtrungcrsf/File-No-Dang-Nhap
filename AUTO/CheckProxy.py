import os
import shutil
import subprocess
import time
import resource


def run_cmd(command):
    return subprocess.run(command, shell=True)


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


os.chdir("/root")

if check_proxy() == "200":
    print("Proxy OK")
else:
    print("Khoi Dong lai 3proxy")
    run_cmd("killall 3proxy >/dev/null 2>&1 || true")
    set_ulimit()
    start_3proxy()

    if wait_proxy_ok():
        print("Proxy Hoat Dong")
    else:
        print("Proxy Khong Hoat Dong")
        subprocess.Popen("cd /root && python3 /root/CheckProxy.py", shell=True)
