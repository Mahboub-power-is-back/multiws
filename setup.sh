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

# System version number
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
mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain
touch /etc/xray/scdomain /etc/v2ray/scdomain

echo -e "[ ${BBlue}NOTES${NC} ] Before we go.. "
sleep 0.5
echo -e "[ ${BBlue}NOTES${NC} ] I need check your headers first.."
sleep 0.5
echo -e "[ ${BGreen}INFO${NC} ] Checking headers"
sleep 0.5

totet=$(uname -r)
REQUIRED_PKG="linux-headers-$totet"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo -e "[ ${BRed}WARNING${NC} ] Try to install ...."
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    apt-get --yes install $REQUIRED_PKG
    echo -e "[ ${BBlue}NOTES${NC} ] If error you need to do this:"
    echo -e "[ ${BBlue}NOTES${NC} ] apt update && apt upgrade -y && reboot"
    read -p "Press enter to continue..."
else
    echo -e "[ ${BGreen}INFO${NC} ] Oke installed"
fi

secs_to_human() {
    echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}

start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

echo -e "[ ${BGreen}INFO${NC} ] Preparing the install file"
apt install git curl -y >/dev/null 2>&1
apt install python -y >/dev/null 2>&1
echo -e "[ ${BGreen}INFO${NC} ] Installation file is ready"
sleep 0.5

mkdir -p /var/lib/ >/dev/null 2>&1
echo "IP=" >> /var/lib/ipvps.conf

# -------------------- DOMAIN SELECTION --------------------
echo -e "$BBlue                     SETUP DOMAIN VPS     $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
echo -e "$BGreen 1. Use Domain Random / Gunakan Domain Random $NC"
echo -e "$BGreen 2. Choose Your Own Domain / Gunakan Domain Sendiri $NC"
echo -e "$BYellow----------------------------------------------------------$NC"

read -rp " input 1 or 2 / pilih 1 atau 2 : " dns
dns=${dns:-1}  # default to 1

if [[ "$dns" == "1" ]]; then
    echo -e "[${BGreen}INFO${NC}] Using Random Domain..."
    ( /bin/bash /root/scripts/cf ) || { echo -e "[${BRed}ERROR${NC}] Cloudflare script failed, continuing..."; }
elif [[ "$dns" == "2" ]]; then
    read -rp "Enter Your Domain / masukan domain : " dom
    if [[ -z "$dom" ]]; then
        echo -e "[${BRed}ERROR${NC}] No domain entered. Using random domain instead."
        ( /bin/bash /root/scripts/cf ) || true
    else
        echo -e "[${BGreen}INFO${NC}] Using Custom Domain: $dom"
        mkdir -p /root/xray /etc/xray /etc/v2ray
        echo "$dom" | tee /root/domain /etc/xray/domain /etc/v2ray/domain /root/scdomain /root/xray/scdomain > /dev/null
    fi
else
    echo -e "[${BRed}ERROR${NC}] Invalid selection, using random domain..."
    ( /bin/bash /root/scripts/cf ) || true
fi

echo -e "[${BGreen}INFO${NC}] Domain setup complete, continuing installation..."
sleep 1
# ------------------------------------------------------------

#install ssh ovpn
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install SSH Websocket           $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh

# Install Xray
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install XRAY              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh && chmod +x insshws.sh && ./insshws.sh
clear

cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

# Clean logs if exist
rm -f /root/log-install.txt /etc/afak.conf
for f in ssh vmess vless trojan shadowsocks; do
  [[ -f /etc/log-create-$f.log ]] || echo "Log $f Account" > /etc/log-create-$f.log
done

history -c
serverV=$(curl -sS https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/menu/versi)
echo $serverV > /opt/.ver
curl -sS ipv4.icanhazip.com > /etc/myipvps

secs_to_human "$(($(date +%s) - ${start}))" | tee -a log-install.txt
echo -e ""
echo " Auto reboot in 10 Seconds "
sleep 10
rm -rf setup.sh
reboot
