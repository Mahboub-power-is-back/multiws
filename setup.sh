#!/bin/bash

# -----------------------------
# MAHBOUB RED LOGO
# -----------------------------
print_logo() {
RED='\033[0;31m'
NC='\033[0m'
cat << EOF
${RED}==================================================================
 __  __       _    _     _    _    ____  ____  ____  
|  \/  | __ _| | _| |__ | | _| |  |  _ \/ ___|| __ ) 
| |\/| |/ _\` | |/ / '_ \| |/ / |  | | | \___ \|  _ \
| |  | | (_| |   <| | | |   <| |__| |_| |___) | |_) |
|_|  |_|\__,_|_|\_\_| |_|_|\_\____|____/|____/|____/ 
                                                      
==================================================================${NC}
EOF
}

# -----------------------------
# PROGRESS BAR
# -----------------------------
progress_bar() {
    local msg="$1"
    local steps=24
    local duration=${2:-1}
    printf "%s... " "$msg"
    for i in $(seq 1 $steps); do
        printf "█"
        sleep $(echo "$duration/$steps" | bc -l)
    done
    printf " Done\n"
}

# -----------------------------
# RUN COMMAND WITH PROGRESS
# -----------------------------
run_with_progress() {
    local cmd="$1"
    local msg="$2"
    progress_bar "$msg"
    bash -c "$cmd" &>/dev/null
}

# -----------------------------
# DOMAIN SETUP FIRST
# -----------------------------
clear
print_logo
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
    run_with_progress "wget -q -O /root/scripts/cf $CF_URL && dos2unix /root/scripts/cf && chmod +x /root/scripts/cf && bash /root/scripts/cf" "Setting Random Domain via Cloudflare"
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

# -----------------------------
# CREATE LOG FILE
# -----------------------------
LOG="/root/log-install.txt"
> "$LOG"

# -----------------------------
# SYSTEM UPDATE & DEPENDENCIES
# -----------------------------
run_with_progress "apt update -y && apt upgrade -y" "Updating system"
run_with_progress "apt install -y git curl wget python3 dos2unix" "Installing dependencies"

# -----------------------------
# SSH WebSocket Installation
# -----------------------------
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "Installing SSH WebSocket"

# -----------------------------
# Xray Installation
# -----------------------------
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "Installing Xray"

# -----------------------------
# SSH over WS Installation
# -----------------------------
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "Installing SSH over WebSocket"

# -----------------------------
# LOG SERVICE PORTS
# -----------------------------
cat >> "$LOG" << EOF
===================== SERVICES & PORTS =====================
- OpenSSH                  : 22
- SSH Websocket            : 80
- SSH SSL Websocket        : 443
- Stunnel4                 : 222, 777
- Dropbear                 : 109, 143
- Badvpn                   : 7100-7900
- Nginx                    : 81
- Vmess WS TLS             : 443
- Vless WS TLS             : 443
- Trojan WS TLS            : 443
- Shadowsocks WS TLS       : 443
- Vmess WS none TLS        : 80
- Vless WS none TLS        : 80
- Trojan WS none TLS       : 80
- Shadowsocks WS none TLS  : 80
- Vmess gRPC               : 443
- Vless gRPC               : 443
- Trojan gRPC              : 443
- Shadowsocks gRPC         : 443
============================================================
EOF

# -----------------------------
# CLEAN UP TEMP FILES
# -----------------------------
run_with_progress "rm -f /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh" "Cleaning up temporary files"

# -----------------------------
# FINISHED
# -----------------------------
echo -e "\nAll installations completed!"
echo "Check installed service ports in $LOG"
