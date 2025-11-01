#!/bin/bash

# ----------------------------
# VPS Installer with Key Check
# ----------------------------

KEY_DB="/root/keys.db"  # copy from bot VPS via scp if needed

read -p "Enter your license key: " USER_KEY

# Lookup key
LINE=$(grep -E "^$USER_KEY\|" "$KEY_DB" || true)
if [ -z "$LINE" ]; then
    echo "❌ Invalid key. Installation aborted."
    exit 1
fi

KEY=$(echo "$LINE" | cut -d'|' -f1)
IP=$(echo "$LINE" | cut -d'|' -f2)
EXP=$(echo "$LINE" | cut -d'|' -f3)

# Check expiration
if [[ $(date -d "$EXP" +%s) -lt $(date +%s) ]]; then
    echo "❌ Key expired. Contact admin for renewal."
    exit 1
fi

# Optional: restrict by IP
USER_IP=$(curl -s ifconfig.me)
if [ "$USER_IP" != "$IP" ]; then
    echo "❌ This key is bound to IP $IP. Your IP: $USER_IP"
    exit 1
fi

echo "✅ Key valid. Proceeding with installation..."
cd /root || exit
rm -f setup.sh >/dev/null 2>&1
clear

# ------------------------------------------------------------------
# Colors
# ------------------------------------------------------------------
NC=$'\e[0m'
RED=$'\e[1;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
TYBLUE=$'\e[1;36m'
BRED=$'\e[1;31m'
BGREEN=$'\e[1;32m'
BYELLOW=$'\e[1;33m'
BBLUE=$'\e[1;34m'

# Helper colored echos
p_purple() { printf "%b%s%b\n" $'\e[35;1m' "$*" "$NC"; }
p_tyblue() { printf "%b%s%b\n" $'\e[36;1m' "$*" "$NC"; }
p_yellow() { printf "%b%s%b\n" $'\e[33;1m' "$*" "$NC"; }
p_green() { printf "%b%s%b\n" $'\e[32;1m' "$*" "$NC"; }
p_red() { printf "%b%s%b\n" $'\e[31;1m' "$*" "$NC"; }

# ------------------------------------------------------------------
# Root check
# ------------------------------------------------------------------
if [ "${EUID:-0}" -ne 0 ]; then
    echo "You need to run this script as root"
    sleep 3
    exit 1
fi

# Virtualization check
if [ "$(systemd-detect-virt 2>/dev/null)" = "openvz" ]; then
    echo "OpenVZ is not supported. For VPS with KVM/VMware ONLY"
    sleep 3
    exit 1
fi

# ------------------------------------------------------------------
# Ensure /etc/hosts contains the hostname mapping
# ------------------------------------------------------------------
localip=$(hostname -I 2>/dev/null | awk '{print $1}')
myhost=$(hostname)
if ! grep -q -w "$myhost" /etc/hosts 2>/dev/null; then
    if [ -n "$localip" ]; then
        echo "$localip $myhost" >> /etc/hosts
    else
        echo "127.0.0.1 $myhost" >> /etc/hosts
    fi
fi

# ------------------------------------------------------------------
# Create required directories and files
# ------------------------------------------------------------------
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain

# ------------------------------------------------------------------
# Startup messages
# ------------------------------------------------------------------
printf "[ %bNOTES%b ] Before we go..\n" "$BBLUE" "$NC"
sleep 0.4
printf "[ %bNOTES%b ] Checking kernel headers..\n" "$BBLUE" "$NC"
sleep 0.4
printf "[ %bINFO%b ] Checking headers\n" "$BGREEN" "$NC"
sleep 0.4

# ------------------------------------------------------------------
# Check for linux-headers
# ------------------------------------------------------------------
kernelver=$(uname -r)
required_pkg="linux-headers-$kernelver"
if ! dpkg-query -W --showformat='${Status}\n' "$required_pkg" 2>/dev/null | grep -q "install ok installed"; then
    printf "[ %bWARNING%b ] %s not found. Installing...\n" "$BRED" "$NC" "$required_pkg"
    apt-get update -y >/dev/null 2>&1 || true
    apt-get --yes install "$required_pkg" || {
        printf "[ %bERROR%b ] Could not install %s. Please run apt update/upgrade then rerun this script\n" "$BRED" "$NC" "$required_pkg"
        read -rp "Press Enter to exit..." _
        exit 1
    }
else
    printf "[ %bINFO%b ] Headers installed (%s)\n" "$BGREEN" "$NC" "$required_pkg"
fi

# ------------------------------------------------------------------
# Utility functions & timer
# ------------------------------------------------------------------
secs_to_human() {
    printf "Installation time : %d hours %d minutes %d seconds\n" \
      "$(( $1 / 3600 ))" "$(( ($1 / 60) % 60 ))" "$(( $1 % 60 ))"
}

start_time=$(date +%s)

# timezone and kernel tweaks
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime 2>/dev/null || true
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

# ------------------------------------------------------------------
# Prepare basic tools
# ------------------------------------------------------------------
printf "[ %bINFO%b ] Preparing the install environment\n" "$BGREEN" "$NC"
DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y git curl python3 jq dos2unix wget >/dev/null 2>&1 || true
printf "[ %bINFO%b ] Installation environment ready\n" "$BGREEN" "$NC"
sleep 0.4

echo "IP=" > /var/lib/ipvps.conf

# ------------------------------------------------------------------
# Domain configuration menu
# ------------------------------------------------------------------
clear
printf "┌─────────────────────────────┐\n"
printf "│   DOMAIN CONFIGURATION MENU │\n"
printf "└─────────────────────────────┘\n"
printf "  [1] Use Random Domain\n"
printf "  [2] Use Your Own Domain\n"
printf "Select option (1/2): "

read -r dns
case "$dns" in
  1)
    mkdir -p /root/scripts
    CF_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/cf"
    wget -q -O /root/scripts/cf "$CF_URL"
    dos2unix /root/scripts/cf >/dev/null 2>&1
    chmod +x /root/scripts/cf
    bash /root/scripts/cf || { echo "[ERROR] Cloudflare script failed"; exit 1; }
    ;;
  2)
    printf "Enter your domain: "
    read -r dom
    if [ -z "$dom" ]; then
        echo "[ERROR] Empty domain. Exiting."
        exit 1
    fi
    echo "IP=$dom" > /var/lib/ipvps.conf
    echo "$dom" > /root/scdomain
    echo "$dom" > /etc/xray/scdomain
    echo "$dom" > /etc/xray/domain
    echo "$dom" > /etc/v2ray/domain
    echo "$dom" > /root/domain
    ;;
  *)
    echo "[ERROR] Invalid selection. Exiting."
    exit 1
    ;;
esac

# ------------------------------------------------------------------
# Progress bar & spinner
# ------------------------------------------------------------------
printf "Initializing..."
for i in {1..24}; do
    printf "█"
    sleep 0.04
done
printf " Done\n"

spinner=( '|' '/' '-' '\' )
printf "Finalizing "
for i in {1..12}; do
    idx=$(( i % ${#spinner[@]} ))
    printf "\b%c" "${spinner[$idx]}"
    sleep 0.07
done
printf "\b OK\n"

# ------------------------------------------------------------------
# Install services
# ------------------------------------------------------------------
for script in ssh-vpn.sh ins-xray.sh insshws.sh; do
    URL="https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/${script%%.*}/${script}"
    wget -q -O /root/$script "$URL"
    chmod +x /root/$script
    /bin/bash /root/$script || echo "[WARN] $script failed, skipping"
done

# ------------------------------------------------------------------
# Setup .profile
# ------------------------------------------------------------------
cat > /root/.profile <<'EOF'
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu
EOF
chmod 644 /root/.profile

# ------------------------------------------------------------------
# Log installation info
# ------------------------------------------------------------------
LOG="/root/log-install.txt"
{
    echo ""
    printf "┌─────────────────────────────┐\n"
    printf "│      SERVICE & PORTS        │\n"
    printf "└─────────────────────────────┘\n"
    echo "   - OpenSSH                  : 22"
    echo "   - SSH Websocket            : 80"
    echo "   - SSH SSL Websocket        : 443"
    echo "   - Stunnel4                 : 222, 777"
    echo "   - Dropbear                 : 109, 143"
    echo "   - UDP CUSTOM               : 1-65535"
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
} >> "$LOG"

# ------------------------------------------------------------------
# Clear history & finish
# ------------------------------------------------------------------
history -c 2>/dev/null || true
end_time=$(date +%s)
secs_to_human $((end_time - start_time)) | tee -a "$LOG"

echo "Auto reboot in 10 seconds..."
sleep 10
rm -f /root/setup.sh >/dev/null 2>&1
reboot
