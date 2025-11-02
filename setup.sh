#!/bin/bash
# MAHBOUB Full Installer (fixed domain & full log)
set +e
cd || exit 1
rm -f setup.sh
clear

# === Colors ===
red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; tyblue='\e[1;36m'
BRed='\e[1;31m'; BGreen='\e[1;32m'; BYellow='\e[1;33m'; BBlue='\e[1;34m'
NC='\e[0m'

purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

LOG="/root/log-install.txt"
LASTLOG="/root/last-install.log"
: > "$LOG"
: > "$LASTLOG"

cd /root || exit 1

# Root check
if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  sleep 5
  exit 1
fi

# Virtualization check
if [ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]; then
  echo "OpenVZ is not supported"
  echo "For VPS with KVM and VMWare virtualization ONLY"
  sleep 5
  exit 1
fi

# Ensure required dirs & files exist
mkdir -p /etc/xray /etc/v2ray /var/lib
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain
: > /root/domain
: > /root/scdomain

# helper: wait for apt lock
wait_for_apt() {
  local t=0
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
        fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    sleep 1
    t=$((t+1))
    if [ $t -ge 180 ]; then
      echo "[ERROR] apt/dpkg lock not released after 180s" >> "$LASTLOG"
      return 1
    fi
  done
  return 0
}

apt_safe() {
  wait_for_apt || return 1
  DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Options::="--force-confdef" \
    -o DPkg::Options::="--force-confold" "$@" >> "$LASTLOG" 2>&1
}

secs_to_human() {
  echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}

start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

echo -e "[ ${BBlue}NOTES${NC} ] Preparing the install file" | tee -a "$LOG"
# update & install basic deps
apt_safe update || apt-get update -y >> "$LASTLOG" 2>&1
apt_safe upgrade || apt-get upgrade -y >> "$LASTLOG" 2>&1
apt_safe install curl wget jq git python3 dos2unix bc >/dev/null 2>&1 || apt-get install -y curl wget jq git python3 dos2unix bc >> "$LASTLOG" 2>&1

echo -e "[ ${BGreen}INFO${NC} ] Aight good ... installation file is ready" | tee -a "$LOG"

sleep 0.5
echo -ne "[ ${BGreen}INFO${NC} ] Check permission : " | tee -a "$LOG"
echo -e "$BGreen Permission Accepted!$NC" | tee -a "$LOG"
sleep 1

# default domain and CF credentials (you provided earlier)
MAIN_DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE_ID="8761c8222fe8a4d1249e8563eedf43ee"

# Domain selection
clear
echo -e "$BBlue                     SETUP DOMAIN VPS     $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
echo -e "$BGreen 1. Use Domain Random (Cloudflare) $NC"
echo -e "$BGreen 2. Choose Your Own Domain         $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
read -rp " input 1 or 2 / pilih 1 atau 2 : " dns_choice

# Function to create or update CF record
cf_create_or_update() {
  local subdomain=$1
  local ipaddr=$2
  # check existing
  local resp=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${subdomain}" \
    -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json")
  local recid=$(echo "$resp" | jq -r '.result[0].id // empty')
  if [ -z "$recid" ]; then
    # create
    local create=$(curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"${subdomain}\",\"content\":\"${ipaddr}\",\"ttl\":120,\"proxied\":false}")
    echo "$create"
  else
    # update
    local update=$(curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${recid}" \
      -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"${subdomain}\",\"content\":\"${ipaddr}\",\"ttl\":120,\"proxied\":false}")
    echo "$update"
  fi
}

# Obtain server IP
SERVER_IP=$(curl -s --max-time 8 https://ipv4.icanhazip.com || echo "")

if [ "$dns_choice" = "1" ]; then
  echo -e "${BGreen}[INFO] Generating random subdomain via Cloudflare...${NC}" | tee -a "$LOG"
  sub=$(tr -dc a-z0-9 </dev/urandom | head -c5)
  SUB_DOMAIN="asx-${sub}.${MAIN_DOMAIN}"
  echo "[DEBUG] will create: $SUB_DOMAIN" >> "$LASTLOG"
  # call CF API and capture result
  cf_out=$(cf_create_or_update "$SUB_DOMAIN" "$SERVER_IP" 2>>"$LASTLOG")
  ok=$(echo "$cf_out" | jq -r '.success // false' 2>/dev/null || echo "false")
  if [ "$ok" = "true" ]; then
    echo -e "${BGreen}[SUCCESS] Subdomain created/updated: $SUB_DOMAIN${NC}" | tee -a "$LOG"
  else
    echo -e "${BRed}[ERROR] Cloudflare API failed. Falling back to manual input.${NC}" | tee -a "$LOG"
    echo "CF API response: $cf_out" >> "$LASTLOG"
    read -rp "Enter your domain manually (example: example.com): " SUB_DOMAIN
  fi
elif [ "$dns_choice" = "2" ]; then
  read -rp "Enter Your Domain / masukan domain : " SUB_DOMAIN
  if [ -z "$SUB_DOMAIN" ]; then
    echo -e "${BRed}[ERROR] Domain cannot be empty${NC}" | tee -a "$LOG"
    exit 1
  fi
else
  echo -e "${BRed}[ERROR] Invalid selection${NC}" | tee -a "$LOG"
  exit 1
fi

# Save domain consistently (only to these files)
echo "IP=$SUB_DOMAIN" > /var/lib/ipvps.conf
echo "$SUB_DOMAIN" > /root/scdomain
echo "$SUB_DOMAIN" > /root/domain
echo "$SUB_DOMAIN" > /etc/xray/scdomain
echo "$SUB_DOMAIN" > /etc/xray/domain
echo "$SUB_DOMAIN" > /etc/v2ray/domain

echo -e "${BGreen}Done! Domain set to: $SUB_DOMAIN${NC}" | tee -a "$LOG"
sleep 1
clear

# --------------------- Install SSH Websocket ---------------------
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install SSH Websocket           $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
# download and run; capture output to log
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh >> "$LASTLOG" 2>&1
chmod +x /root/ssh-vpn.sh
bash /root/ssh-vpn.sh >> "$LOG" 2>&1 || echo "[WARN] ssh-vpn script exited with code $?" >> "$LOG"

# --------------------- Install Xray ---------------------
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install XRAY              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh >> "$LASTLOG" 2>&1
chmod +x /root/ins-xray.sh
bash /root/ins-xray.sh >> "$LOG" 2>&1 || echo "[WARN] ins-xray script exited with code $?" >> "$LOG"

# --------------------- Install SSHWS ---------------------
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh >> "$LASTLOG" 2>&1
chmod +x /root/insshws.sh
bash /root/insshws.sh >> "$LOG" 2>&1 || echo "[WARN] insshws script exited with code $?" >> "$LOG"

# Prepare profile menu
cat> /root/.profile << 'END'
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

# Clean up some temp files
rm -f /root/ins-xray.sh /root/insshws.sh /root/ssh-vpn.sh /root/cf >> "$LASTLOG" 2>&1

# Ensure some log files exist
[ -f /etc/log-create-ssh.log ] || echo "Log SSH Account " > /etc/log-create-ssh.log
[ -f /etc/log-create-vmess.log ] || echo "Log Vmess Account " > /etc/log-create-vmess.log
[ -f /etc/log-create-vless.log ] || echo "Log Vless Account " > /etc/log-create-vless.log
[ -f /etc/log-create-trojan.log ] || echo "Log Trojan Account " > /etc/log-create-trojan.log
[ -f /etc/log-create-shadowsocks.log ] || echo "Log Shadowsocks Account " > /etc/log-create-shadowsocks.log

history -c
serverV=$(curl -sS https://raw.githubusercontent.com/givpn/AutoScriptXray/master/menu/versi || echo "1.0")
echo "$serverV" > /opt/.ver 2>/dev/null || true

# record server public ip
curl -sS ipv4.icanhazip.com > /etc/myipvps 2>/dev/null || echo "$SERVER_IP" > /etc/myipvps

# Service status quick check (append outputs)
{
  echo ""
  echo "==================== SERVICE STATUS (quick) ===================="
  for svc in ssh nginx xray dropbear stunnel4 openvpn; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      printf "  %-12s : %s\n" "$svc" "running"
    else
      printf "  %-12s : %s\n" "$svc" "not-running-or-not-installed"
    fi
  done
} >> "$LOG"

# Final summary & service & port list appended to log_install
{
echo ""
echo "=================================================================="
echo "      ___                                    ___         ___      "
echo "     /  /\        ___           ___         /  /\       /__/\     "
echo "    /  /:/_      /  /\         /__/\       /  /::\      \  \:\    "
echo "   /  /:/ /\    /  /:/         \  \:\     /  /:/\:\      \  \:\   "
echo "  /  /:/_/::\  /__/::\          \  \:\   /  /:/~/:/  _____\__\:\  "
echo " /__/:/__\/\:\ \__\/\:\__   ___  \__\:\ /__/:/ /:/  /__/::::::::\ "
echo " \  \:\ /~~/:/    \  \:\/\ /__/\ |  |:| \  \:\/:/   \  \:\~~\~~\/ "
echo "  \  \:\  /:/      \__\::/ \  \:\|  |:|  \  \::/     \  \:\  ~~~  "
echo "   \  \:\/:/       /__/:/   \  \:\__|:|   \  \:\      \  \:\      "
echo "    \  \::/        \__\/     \__\::::/     \  \:\      \  \:\     "
echo "     \__\/                       ~~~~       \__\/       \__\/ 1.0 "
echo "=================================================================="
echo ""
echo "   >>> Service & Port"
echo "   - OpenSSH                  : 22"
echo "   - SSH Websocket            : 80"
echo "   - SSH SSL Websocket        : 443"
echo "   - Stunnel4                 : 222, 777"
echo "   - Dropbear                 : 109, 143"
echo "   - Badvpn                   : 7100-7900"
echo "   - Nginx                    : 81"
echo "   - Vmess WS TLS             : 443"
echo "   - Vless WS TLS             : 443"
echo "   - Trojan WS TLS            : 443"
echo "   - Shadowsocks WS TLS       : 443"
echo "   - Vmess WS none TLS        : 80"
echo "   - Vless WS none TLS        : 80"
echo "   - Trojan WS none TLS       : 80"
echo "   - Shadowsocks WS none TLS  : 80"
echo "   - Vmess gRPC               : 443"
echo "   - Vless gRPC               : 443"
echo "   - Trojan gRPC              : 443"
echo "   - Shadowsocks gRPC         : 443"
echo ""
echo "Domain used : $SUB_DOMAIN"
echo "Server IP   : $(cat /etc/myipvps 2>/dev/null || echo $SERVER_IP)"
echo "Log file    : $LOG"
echo ""
echo "=============================Contact=============================="
echo "---------------------------t.me/givpn-----------------------------"
echo "=================================================================="
} >> "$LOG"

# append last 200 lines of LASTLOG to main LOG for debugging
echo "" >> "$LOG"
echo "----------------- Installer tail (last 200 lines) -----------------" >> "$LOG"
tail -n 200 "$LASTLOG" >> "$LOG" 2>/dev/null || true

secs_to_human "$(($(date +%s) - ${start}))" | tee -a "$LOG"
echo "" >> "$LOG"

# cleanup
rm -f /root/ins-xray.sh /root/insshws.sh /root/ssh-vpn.sh /root/cf 2>/dev/null

echo -e "${BGreen}===============================================${NC}"
echo -e "${BGreen}            INSTALLATION COMPLETED             ${NC}"
echo -e "${BGreen}===============================================${NC}"
echo -e "${BBlue}Domain: $SUB_DOMAIN${NC}"
echo -e "${BYellow}Log file: $LOG${NC}"
echo -e "${BYellow}System will reboot in 10 seconds...${NC}"
sleep 10
reboot
