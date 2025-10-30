#!/usr/bin/env bash
#
# Fixed full installer script (cleaned, safer prompts, color escapes fixed)
# Keep the original reminders / banner text at the top
#
# NOTE: run as root (script checks automatically)

# ------------------------------------------------------------------
# Reminders from original
# ------------------------------------------------------------------
echo ""
echo "=================================================================="
echo "    cari apa..?? harta tahta hanya sementara ingat masih ada kehidupan setelah kematian"
echo "    jangan lupa sholat ingat ajal menantimu"
echo "    dibawah ini bukan cd kaset ya"
echo ""

# ------------------------------------------------------------------
# Cleanup old setup file (if any) and chdir root
# ------------------------------------------------------------------
cd /root || exit 1
rm -f setup.sh >/dev/null 2>&1
clear

# ------------------------------------------------------------------
# Colors (use $'...' so escapes become real bytes)
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

# helper colored-echos (safely)
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
    echo "OpenVZ is not supported. For VPS with KVM and VMWare virtualization ONLY"
    sleep 3
    exit 1
fi

# ------------------------------------------------------------------
# Ensure /etc/hosts contains the hostname mapping (if absent)
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
# Print small startup notes (friendly)
# ------------------------------------------------------------------
printf "[ %bNOTES%b ] Before we go..\n" "$BBLUE" "$NC"
sleep 0.4
printf "[ %bNOTES%b ] I will check your kernel headers first..\n" "$BBLUE" "$NC"
sleep 0.4
printf "[ %bINFO%b ] Checking headers\n" "$BGREEN" "$NC"
sleep 0.4

# ------------------------------------------------------------------
# Check for linux-headers for current kernel
# ------------------------------------------------------------------
kernelver=$(uname -r)
required_pkg="linux-headers-$kernelver"
if ! dpkg-query -W --showformat='${Status}\n' "$required_pkg" 2>/dev/null | grep -q "install ok installed"; then
    printf "[ %bWARNING%b ] %s not found. Attempting to install.\n" "$BRED" "$NC" "$required_pkg"
    apt-get update -y >/dev/null 2>&1 || true
    apt-get --yes install "$required_pkg" || {
        printf "[ %bERROR%b ] Could not install %s. Run:\n  apt update && apt upgrade -y && reboot\nthen rerun this script\n" "$BRED" "$NC" "$required_pkg"
        read -rp "Press Enter to exit..." _
        exit 1
    }
else
    printf "[ %bINFO%b ] Headers installed (%s)\n" "$BGREEN" "$NC" "$required_pkg"
fi

# Re-check quickly
if ! dpkg -s "$required_pkg" >/dev/null 2>&1; then
    printf "[ %bERROR%b ] Required headers still missing. Exiting.\n" "$BRED" "$NC"
    exit 1
fi

# ------------------------------------------------------------------
# Utility functions & timer
# ------------------------------------------------------------------
secs_to_human() {
    printf "Installation time : %d hours %d minute's %d seconds\n" \
      "$(( $1 / 3600 ))" "$(( ($1 / 60) % 60 ))" "$(( $1 % 60 ))"
}

start_time=$(date +%s)

# timezone and kernel tweaks (as original)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime 2>/dev/null || true
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

# ------------------------------------------------------------------
# Prepare basic tools
# ------------------------------------------------------------------
printf "[ %bINFO%b ] Preparing the install file\n" "$BGREEN" "$NC"
DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y git curl python3 jq dos2unix wget >/dev/null 2>&1 || true
printf "[ %bINFO%b ] Installation file is ready\n" "$BGREEN" "$NC"
sleep 0.4

# mark IP config file
echo "IP=" > /var/lib/ipvps.conf

# ------------------------------------------------------------------
# DOMAIN CONFIG MENU (cyber/hacker style)
# ------------------------------------------------------------------
clear
GREEN=$'\e[0;32m'
LIGHTGREEN=$'\e[1;32m'
CYAN=$'\e[0;36m'
NC=$'\e[0m'

printf "%b┌──────────────────────────────────────────────────────────┐%b\n" "$GREEN" "$NC"
printf "%b│%b%40s%10b│%b\n" "$GREEN" "$CYAN" "DOMAIN CONFIGURATION MENU" "$GREEN" "$NC"
printf "%b└──────────────────────────────────────────────────────────┘%b\n" "$GREEN" "$NC"
printf "%b  [1] %bUse Random Domain%b\n" "$LIGHTGREEN" "$NC" "$NC"
printf "%b  [2] %bUse Your Own Domain%b\n" "$LIGHTGREEN" "$NC" "$NC"
printf "%b────────────────────────────────────────────────────────────%b\n" "$GREEN" "$NC"
printf "%bSelect option (%b1%b/%b2%b): %b" "$CYAN" "$LIGHTGREEN" "$CYAN" "$LIGHTGREEN" "$CYAN" "$NC"

# read without embedded escape sequences
read -r dns

# validate and handle input
case "$dns" in
  1)
    # Ensure dependencies present
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y curl jq dos2unix wget || true

    # download cf helper script into /root/scripts
    mkdir -p /root/scripts
    CF_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/cf"
    if ! wget -q -O /root/scripts/cf "$CF_URL"; then
        printf "[ %bERROR%b ] Failed to download Cloudflare helper: %s\n" "$BRED" "$NC" "$CF_URL"
        exit 1
    fi
    dos2unix /root/scripts/cf >/dev/null 2>&1 || true
    chmod +x /root/scripts/cf || true

    # run it and fail safe
    bash /root/scripts/cf || {
        printf "[ %bERROR%b ] Cloudflare script failed. Exiting.\n" "$BRED" "$NC"
        exit 1
    }
    ;;
  2)
    printf "%bEnter your domain: %b" "$CYAN" "$NC"
    read -r dom
    if [ -z "$dom" ]; then
        printf "[ %bERROR%b ] Empty domain. Exiting.\n" "$BRED" "$NC"
        exit 1
    fi
    # persist domain
    printf "IP=%s\n" "$dom" > /var/lib/ipvps.conf
    printf "%s\n" "$dom" > /root/scdomain
    printf "%s\n" "$dom" > /etc/xray/scdomain
    printf "%s\n" "$dom" > /etc/xray/domain
    printf "%s\n" "$dom" > /etc/v2ray/domain
    printf "%s\n" "$dom" > /root/domain
    ;;
  *)
    printf "\n%b[ %bERROR%b ] Invalid selection. Exiting.%b\n" "$BRED" "$NC" "$BRED" "$NC"
    exit 1
    ;;
esac

# ------------------------------------------------------------------
# Loading animation (progress bar + spinner)
# ------------------------------------------------------------------
printf "\n%bInitializing...%b\n" "$CYAN" "$NC"
total=24
for ((i=1; i<=total; i++)); do
    printf "%b█%b" "$GREEN" "$NC"
    sleep 0.04
done
printf " %bDone%b\n" "$LIGHTGREEN" "$NC"

spinner=( '|' '/' '-' '\' )
printf "%bFinalizing " "$CYAN"
for i in {1..12}; do
    idx=$(( i % ${#spinner[@]} ))
    printf "\b%b%c%b" "$LIGHTGREEN" "${spinner[$idx]}" "$NC"
    sleep 0.07
done
printf "\b%b OK%b\n\n" "$LIGHTGREEN" "$NC"

# ------------------------------------------------------------------
# Install services (as in original)
# ------------------------------------------------------------------

printf "%b-----------------------------------%b\n" "$YELLOW" "$NC"
printf "%b      Install SSH Websocket           %b\n" "$BGREEN" "$NC"
printf "%b-----------------------------------%b\n" "$YELLOW" "$NC"
sleep 0.5
# download and run ssh installer (note: maintainers may change)
if wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh"; then
    chmod +x /root/ssh-vpn.sh
    /bin/bash /root/ssh-vpn.sh
else
    printf "[ %bWARN%b ] Could not download ssh-vpn.sh, skipping.\n" "$BYELLOW" "$NC"
fi

# Install Xray
printf "%b-----------------------------------%b\n" "$YELLOW" "$NC"
printf "%b          Install XRAY              %b\n" "$BGREEN" "$NC"
printf "%b-----------------------------------%b\n" "$YELLOW" "$NC"
sleep 0.5
if wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh"; then
    chmod +x /root/ins-xray.sh
    /bin/bash /root/ins-xray.sh
else
    printf "[ %bWARN%b ] Could not download ins-xray.sh, skipping.\n" "$BYELLOW" "$NC"
fi

if wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh"; then
    chmod +x /root/insshws.sh
    /bin/bash /root/insshws.sh
else
    printf "[ %bWARN%b ] Could not download insshws.sh, skipping.\n" "$BYELLOW" "$NC"
fi

# ------------------------------------------------------------------
# Setup .profile to launch menu on login
# ------------------------------------------------------------------
cat > /root/.profile <<'END_PROFILE'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END_PROFILE
chmod 644 /root/.profile

# ------------------------------------------------------------------
# Write a clean, framed log (to /root/log-install.txt)
# ------------------------------------------------------------------
LOG="/root/log-install.txt"
{
    echo ""
    printf "┌───────────────────────────────────────────────────────────────┐\n"
    printf "│                         SERVICE & PORTS                                  │\n"
    printf "└───────────────────────────────────────────────────────────────┘\n"
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
    printf "┌───────────────────────────────────────────────────────────────┐\n"
    printf "│                          CHANGE LOG                                       │\n"
    printf "└───────────────────────────────────────────────────────────────┘\n"
    echo "   MAHBOUB : Improved log formatting & added Telegram contact"
    echo ""
    printf "┌───────────────────────────────────────────────────────────────┐\n"
    printf "│                           CONTACT                                         │\n"
    printf "└───────────────────────────────────────────────────────────────┘\n"
    echo "   Telegram : t.me/vpsplus71"
    echo ""
} >>"$LOG"

# Ensure per-service account log files exist
for log in ssh vmess vless trojan shadowsocks; do
    file="/etc/log-create-$log.log"
    if [ ! -f "$file" ]; then
        printf "Log %s Account\n" "$log" > "$file"
    fi
done

# Clear history for privacy (as original)
history -c 2>/dev/null || true

# Final message and timing
end_time=$(date +%s)
printf "%bInstallation Finished!%b\n" "$BGREEN" "$NC"
secs_to_human $((end_time - start_time)) | tee -a "$LOG"

printf "%bAuto reboot in 10 seconds...%b\n" "$YELLOW" "$NC"
sleep 10

# cleanup & reboot
rm -f /root/setup.sh >/dev/null 2>&1
reboot
