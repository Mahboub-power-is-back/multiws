#!/bin/bash
# cari apa..?? harta tahta hanya sementara ingat masih ada kehidupan setelah kematian
# jangan lupa sholat ingat ajal menantimu
# dibawah ini bukan cd kaset ya
cd
rm -rf setup.sh
clear
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
BRed='\e[1;31m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
BBlue='\e[1;34m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
cd /root

#System version number
if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    sleep 5
    exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "OpenVZ is not supported"
    clear
    echo "For VPS with KVM and VMWare virtualization ONLY"
    sleep 5
    exit 1
fi

localip=$(hostname -I | cut -d\  -f1)
hst=( `hostname` )
dart=$(cat /etc/hosts | grep -w `hostname` | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
    echo "$localip $(hostname)" >> /etc/hosts
fi

# buat folder
mkdir -p /etc/xray
mkdir -p /etc/v2ray
touch /etc/xray/domain
touch /etc/v2ray/domain
touch /etc/xray/scdomain
touch /etc/v2ray/scdomain

echo -e "[ ${BBlue}NOTES${NC} ] Before we go.. "
sleep 0.5
echo -e "[ ${BBlue}NOTES${NC} ] I need check your headers first.."
sleep 0.5
echo -e "[ ${BGreen}INFO${NC} ] Checking headers"
sleep 0.5
totet=`uname -r`
REQUIRED_PKG="linux-headers-$totet"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    sleep 0.5
    echo -e "[ ${BRed}WARNING${NC} ] Try to install ...."
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    apt-get --yes install $REQUIRED_PKG
    sleep 0.5
    echo ""
    sleep 0.5
    echo -e "[ ${BBlue}NOTES${NC} ] If error you need.. to do this"
    sleep 0.5
    echo ""
    sleep 0.5
    echo -e "[ ${BBlue}NOTES${NC} ] apt update && apt upgrade -y && reboot"
    sleep 0.5
    echo ""
    sleep 0.5
    echo -e "[ ${BBlue}NOTES${NC} ] After this"
    sleep 0.5
    echo -e "[ ${BBlue}NOTES${NC} ] Then run this script again"
    echo -e "[ ${BBlue}NOTES${NC} ] enter now"
    read
else
    echo -e "[ ${BGreen}INFO${NC} ] Oke installed"
fi

ttet=`uname -r`
ReqPKG="linux-headers-$ttet"
if ! dpkg -s $ReqPKG >/dev/null 2>&1; then
    rm /root/setup.sh >/dev/null 2>&1
    exit
else
    clear
fi

secs_to_human() {
    echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}
start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

echo -e "[ ${BGreen}INFO${NC} ] Preparing the install file"
apt install git curl python -y >/dev/null 2>&1
echo -e "[ ${BGreen}INFO${NC} ] Aight good ... installation file is ready"
sleep 0.5
echo -ne "[ ${BGreen}INFO${NC} ] Check permission : "
echo -e "$BGreen Permission Accepted!$NC"
sleep 2

mkdir -p /var/lib/ >/dev/null 2>&1
echo "IP=" >> /var/lib/ipvps.conf

echo ""
clear
# Colors
NC='\033[0m'
GREEN='\033[0;32m'
LIGHTGREEN='\033[1;32m'
CYAN='\033[0;36m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${CYAN}                 DOMAIN CONFIGURATION MENU               ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "${LIGHTGREEN}  [1]${NC} Use Random Domain"
echo -e "${LIGHTGREEN}  [2]${NC} Use Your Own Domain"
echo -e "${GREEN}────────────────────────────────────────────────────────────${NC}"
read -rp " Select option ${CYAN}(1/2)${NC}: " dns

# Hacker Loading Effect
echo -e "${CYAN}\nInitializing..."
sleep 0.3
for i in {1..20}; do
    echo -ne "${GREEN}█${NC}"
    sleep 0.05
done
echo -e "\n${LIGHTGREEN}Done!${NC}\n"

if test $dns -eq 1; then
    # Ensure dependencies
    apt update
    apt install -y curl jq dos2unix

    # Ensure cf script exists
    mkdir -p /root/scripts
    wget -O /root/scripts/cf https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/ssh/cf
    dos2unix /root/scripts/cf
    chmod +x /root/scripts/cf

    # Run cf script safely
    bash /root/scripts/cf
    if [ $? -ne 0 ]; then
        echo -e "[${BRed}ERROR${NC}] Cloudflare script failed, exiting"
        exit 1
    fi
elif test $dns -eq 2; then
    read -rp "Enter Your Domain / masukan domain : " dom
    echo "IP=$dom" > /var/lib/ipvps.conf
    echo "$dom" > /root/scdomain
    echo "$dom" > /etc/xray/scdomain
    echo "$dom" > /etc/xray/domain
    echo "$dom" > /etc/v2ray/domain
    echo "$dom" > /root/domain
else 
    echo -e "[${BRed}ERROR${NC}] Invalid selection"
    exit 1
fi

echo -e "${BGreen}Done!${NC}"
sleep 2
clear

#install ssh ovpn
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install SSH Websocket           $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/ssh/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh

#Install Xray
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install XRAY              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/xray/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh && chmod +x insshws.sh && ./insshws.sh
clear

# Setup .profile to launch menu
cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

# Logs
for log in ssh vmess vless trojan shadowsocks; do
    if [ ! -f "/etc/log-create-$log.log" ]; then
        echo "Log $log Account " > /etc/log-create-$log.log
    fi
done

history -c

# Install finished
echo -e "${BGreen}Installation Finished!${NC}"
secs_to_human "$(($(date +%s) - ${start}))" | tee -a /root/log-install.txt
echo -e "Auto reboot in 10 seconds..."
sleep 10
rm -rf setup.sh
reboot
