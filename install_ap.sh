#!/bin/bash

check_user() {
    user=$(whoami)
    if [ ${user} != 'root' ]; then
        echo -e "\033[1;31m[-]\033[0m This script shoulld be launched with root permissions, for example \"sudo $0\""
        exit 1
    else
        echo -e "\033[1;32m[+]\033[0m Installation is launched. It will take several minutes"
    fi
}

check_driver() {
    readlink /sys/class/net/wlan0/device/driver | rev | cut -d '/' -f 1 | rev
}

install_needed_software() {
    echo -e "\033[1;32m[+]\033[0m Update repositories data"
    apt-get update -y > /dev/null
    software=(hostapd isc-dhcp-server)
    for item in ${software[*]}; do
        search_package=$(dpkg --get-selections ${item})
        if [ `echo ${search_package} | cut -d " " -f 2` != 'install' ]; then
            echo -e "\033[1;33m[!]\033[0m ${item} is absent and will be installed"
            apt-get install ${item} -y --force-yes > /dev/null
            if [ $? == 0 ]; then
                echo -e "\033[1;32m[+]\033[0m ${item} has been installed"
            fi
        else
            echo -e "\033[1;32m[+]\033[0m ${item} is already installed"
        fi
    done
}

stop_interface() {
    echo -e "\033[1;33m[!]\033[0m Down interface wlan0"
    ifdown wlan0
}

set_iptables() {
    echo -e "\033[1;33m[!]\033[0m IPTables settings update"
    iptables -F
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
}

set_files() {
echo -e "\033[1;33m[!]\033[0m Setup configuration files"
cat << EOF > /etc/dhcp/dhcpd.conf
ddns-update-style none;
default-lease-time 600;
max-lease-time 7200;
authoritative;
log-facility local7;

subnet 192.168.42.0 netmask 255.255.255.0 {
range 192.168.42.10 192.168.42.50;
option broadcast-address 192.168.42.255;
option routers 192.168.42.1;
default-lease-time 600;
max-lease-time 7200;
option domain-name "local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

cat << EOF > /etc/default/isc-dhcp-server
INTERFACES="wlan0"
EOF

cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.42.1
    netmask 255.255.255.0

up iptables-restore < /etc/iptables.ipv4.nat
EOF

cat << EOF > /etc/hostapd/hostapd.conf
interface=wlan0
ssid=Pi_AP
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=Raspberry
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

cat << EOF > /etc/default/hostapd
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
}

fix_hostapd() {
    echo -e "\033[1;33m[!]\033[0m Fixing issue with hostapd"
    wget http://adafruit-download.s3.amazonaws.com/adafruit_hostapd_14128.zip
    if [ $? != 0 ]; then
        echo -e "\033[1;31m[-]\033[0m Can't download patch adafruit_hostapd_14128.zip. Exit"
        exit 1
    fi
    unzip adafruit_hostapd_14128.zip
    mv /usr/sbin/hostapd /usr/sbin/hostapd.ORIG
    mv hostapd /usr/sbin
    chmod 755 /usr/sbin/hostapd
}

start_services() {
    service=(hostapd isc-dhcp-server)
    for item in ${service[*]}; do
        service_started=$(service ${item} start)
        if [ $? == 0 ]; then
            echo -e "\033[1;32m[+]\033[0m Service ${item} has been started"
        else
            echo -e "\033[1;33m[!]\033[0m Something went wrong with service ${item}"
        fi
    done
}

make_bootable() {
    service=(hostapd isc-dhcp-server)
    for item in ${service[*]}; do
        service_started=$(update-rc.d ${item} enable)
        if [ $? == 0 ]; then
            echo -e "\033[1;32m[+]\033[0m Service ${item} is bootable now"
        else
            echo -e "\033[1;33m[!]\033[0m Something went wrong ${item} is not bootable. Start it manually after rebooting"
        fi
    done
}

reboot_instance() {
    echo -e "\033[1;33m[!]\033[0m Your Raspberry Pi will be restarted. Access point will be available in 1 minute"
    reboot
}

check_user
driver=$(check_driver)
if [ ${driver} == 'r8188eu' ]; then
    needs_fix='True'
elif [ ${driver} == 'ath9k_htc' ]; then
    needs_fix='False'
else
    echo "\033[1;31m[-]\033[0m Your driver ${driver} is not suported yet. Exit"
    exit 1
fi
stop_interface
install_needed_software
ifconfig wlan0 192.168.42.1
set_files
set_iptables
echo "1" > /proc/sys/net/ipv4/ip_forward
iptables-save > /etc/iptables.ipv4.nat
if [ ${needs_fix} == 'True' ]; then
    fix_hostapd
fi
start_services
make_bootable