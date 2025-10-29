#!/bin/bash
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

if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  sleep 5
  exit 1
fi

if [ "$(systemd-detect-virt)" == "openvz" ]; then
  echo "OpenVZ is not supported"
  sleep 5
  exit 1
fi

localip=$(hostname -I | cut -d\  -f1)
hst=( `hostname` )
dart=$(cat /etc/hosts | grep -w `hostname` | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
  echo "$localip $(hostname)" >> /etc/hosts
fi

mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain

echo -e "[ ${BBlue}NOTES${NC} ] Checking headers..."
sleep 0.5
totet=$(uname -r)
REQUIRED_PKG="linux-headers-$totet"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG | grep "install ok installed")
if [ "" = "$PKG_OK" ]; then
  echo -e "[ ${BRed}WARNING${NC} ] Linux headers missing, continuing anyway..."
  # skip exit
else
  echo -e "[ ${BGreen}INFO${NC} ] Linux headers installed."
fi

secs_to_human() {
  echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}
start=$(date +%s)

ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

apt install git curl python -y >/dev/null 2>&1

mkdir -p /var/lib/
echo "IP=" >> /var/lib/ipvps.conf

echo -e "$BBlue                     SETUP DOMAIN VPS     $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
echo -e "$BGreen 1. Use Domain Random / Gunakan Domain Random $NC"
echo -e "$BGreen 2. Choose Your Own Domain / Gunakan Domain Sendiri $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
read -rp " input 1 or 2 / pilih 1 atau 2 : " dns

if [[ "$dns" == "1" ]]; then
    echo -e "[${BGreen}INFO${NC}] Using Random Domain..."
    if [ -f /root/scripts/cf ]; then
        /bin/bash /root/scripts/cf
    else
        echo -e "[${BRed}WARNING${NC}] /root/scripts/cf not found, skipping..."
    fi
elif [[ "$dns" == "2" ]]; then
    read -rp "Enter Your Domain / masukan domain : " dom
    echo -e "[${BGreen}INFO${NC}] Using Custom Domain: $dom"
    mkdir -p /root/xray /etc/xray /etc/v2ray
    echo "$dom" | tee /root/domain /etc/xray/domain /etc/v2ray/domain /root/scdomain /root/xray/scdomain > /dev/null
else 
    echo -e "[${BRed}ERROR${NC}] Invalid selection, continuing..."
fi

sleep 1

# Install SSH Websocket
echo -e "$BGreen      Install SSH Websocket           $NC"
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O ssh-vpn.sh
if [ -f ssh-vpn.sh ]; then
    chmod +x ssh-vpn.sh
    ./ssh-vpn.sh
else
    echo -e "[${BRed}ERROR${NC}] ssh-vpn.sh download failed, continuing..."
fi

# Install Xray
echo -e "$BGreen          Install XRAY              $NC"
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O ins-xray.sh
if [ -f ins-xray.sh ]; then
    chmod +x ins-xray.sh
    ./ins-xray.sh
else
    echo -e "[${BRed}ERROR${NC}] ins-xray.sh download failed, continuing..."
fi

wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O insshws.sh
if [ -f insshws.sh ]; then
    chmod +x insshws.sh
    ./insshws.sh
else
    echo -e "[${BRed}ERROR${NC}] insshws.sh download failed, continuing..."
fi

# Setup profile
cat> /root/.profile << END
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

echo -e "[${BGreen}INFO${NC}] Installation complete. Rebooting in 10 seconds..."
sleep 10
reboot
