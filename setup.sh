#!/bin/bash
cd
rm -rf setup.sh
clear

# Colors
red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; tyblue='\e[1;36m'
BRed='\e[1;31m'; BGreen='\e[1;32m'; BYellow='\e[1;33m'; BBlue='\e[1;34m'; NC='\e[0m'

purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green()  { echo -e "\\033[32;1m${*}\\033[0m"; }
red()    { echo -e "\\033[31;1m${*}\\033[0m"; }

spinner() {
    local pid=$1 msg="$2" delay=0.1 spin='|/-\'
    printf "%-40s" "$msg"
    while ps -p $pid > /dev/null 2>&1; do
        for i in {1..4}; do
            printf " [%c] " "${spin:0:1}"
            spin=${spin#?}${spin%${spin#?}}
            sleep $delay
            printf "\b\b\b\b\b"
        done
    done
}

run_with_spinner() {
    local cmd="$1" msg="$2"
    eval "$cmd" >/dev/null 2>&1 & pid=$!
    spinner $pid "$msg"; wait $pid
    [[ $? == 0 ]] && echo -e "\033[32m[OK]\033[0m" || echo -e "\033[31m[FAIL]\033[0m"
}

# ROOT CHECK
[[ $EUID -ne 0 ]] && echo "Run as root" && exit
[[ "$(systemd-detect-virt)" == "openvz" ]] && echo "OpenVZ not supported" && exit

# Create folders
mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain

# Install system deps
run_with_spinner "apt update -y" "System Update"
run_with_spinner "apt install git curl wget jq python3 -y" "Installing Dependencies"
echo "IP=" >/var/lib/ipvps.conf

# ------------------------------ DOMAIN SETUP ------------------------------
clear
echo -e "$BBlue                     SETUP DOMAIN VPS     $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
echo -e "$BGreen 1. Use Cloudflare Random Domain $NC"
echo -e "$BGreen 2. Use Your Own Domain $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
read -rp " Choose (1/2): " dns

if [[ $dns == "1" ]]; then
    run_with_spinner "wget -q -O /root/cf https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/cf" "Downloading Domain Engine"
    chmod +x /root/cf
    CF_OUTPUT=$(bash /root/cf)
    dom=$(echo "$CF_OUTPUT" | grep -E -o '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}')
    [[ -z "$dom" ]] && echo -e "${red}[DOMAIN ERROR] Enter domain manually${NC}" && read -rp "Domain: " dom
else
    read -rp "Enter Domain: " dom
fi

# Save domain everywhere
echo "$dom" >/root/domain
echo "$dom" >/root/scdomain
echo "$dom" >/etc/xray/domain
echo "$dom" >/etc/xray/scdomain
echo "$dom" >/etc/v2ray/domain
echo "IP=$dom" >/var/lib/ipvps.conf

echo -e "${BGreen}[SUCCESS] Domain Used → $dom${NC}"
sleep 1; clear

# ------------------------------ INSTALL SERVICES ------------------------------
run_with_spinner "wget -q -O /root/ssh-vpn.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh" "Download SSH / DROPBEAR / STUNNEL"
chmod +x /root/ssh-vpn.sh; ./ssh-vpn.sh

run_with_spinner "wget -q -O /root/ins-xray.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh" "Download XRAY Install Script"
chmod +x /root/ins-xray.sh; ./ins-xray.sh

run_with_spinner "wget -q -O /root/insshws.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh" "Download SSHWS Script"
chmod +x /root/insshws.sh; ./insshws.sh

# ------------------------------ FINISH ------------------------------
history -c
systemctl daemon-reload

echo ""
echo -e "${BGreen}===============================================${NC}"
echo -e "${BGreen}            INSTALLATION COMPLETED             ${NC}"
echo -e "${BGreen}===============================================${NC}"
echo -e "${BBlue}DOMAIN : $dom${NC}"
echo -e "${BBlue}REBOOT IN 10 SECONDS...${NC}"
sleep 10
reboot
