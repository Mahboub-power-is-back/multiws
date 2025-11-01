#!/bin/bash

# =============================
# MAHBOUB INSTALLATION SCRIPT
# =============================

# -----------------------------
# MAHBOUB LOGO (RED)
# -----------------------------
print_logo() {
cat << "EOF"
\033[0;31m==================================================================
 __  __       _    _     _    _    ____  ____  ____  
|  \/  | __ _| | _| |__ | | _| |  |  _ \/ ___|| __ ) 
| |\/| |/ _` | |/ / '_ \| |/ / |  | | | \___ \|  _ \ 
| |  | | (_| |   <| | | |   <| |__| |_| |___) | |_) |
|_|  |_|\__,_|_|\_\_| |_|_|\_\____|____/|____/|____/ 
==================================================================\033[0m
EOF
}

# -----------------------------
# PROGRESS BAR FUNCTION
# -----------------------------
progress_bar() {
    local msg="$1"
    local duration=${2:-1}  # Default duration
    local steps=24
    printf "%s " "$msg"
    for i in $(seq 1 $steps); do
        printf "█"
        sleep $(echo "$duration/$steps" | bc -l)
    done
    printf " OK\n"
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
# START SCRIPT
# -----------------------------
clear
print_logo
sleep 1

# Create log file
LOG="/root/log-install.txt"
> "$LOG"

# -----------------------------
# DOMAIN CONFIGURATION
# -----------------------------
printf "┌─────────────────────────────┐\n"
printf "│   DOMAIN CONFIGURATION MENU │\n"
printf "└─────────────────────────────┘\n"
printf "  [1] Use Random Domain (Cloudflare)\n"
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
    ;;
  *)
    echo "[ERROR] Invalid selection. Exiting."
    exit 1
    ;;
esac

# Save domain to config files
mkdir -p /etc/xray /etc/v2ray
echo "$dom" > /var/lib/ipvps.conf
echo "$dom" > /root/scdomain
echo "$dom" > /etc/xray/scdomain
echo "$dom" > /etc/xray/domain
echo "$dom" > /etc/v2ray/domain
echo "$dom" > /root/domain

# -----------------------------
# SYSTEM UPDATE & DEPENDENCIES
# -----------------------------
run_with_progress "apt update -y && apt upgrade -y" "[SYS] Updating System"
run_with_progress "apt install -y git curl wget python3 dos2unix" "[SYS] Installing Dependencies"

# -----------------------------
# INSTALL SERVICES
# -----------------------------
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"
run_with_progress "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[SSHWS] Installing SSH over WebSocket"

# -----------------------------
# LOG SERVICE PORTS
# -----------------------------
echo "=================================================================="  | tee -a "$LOG"
echo ""  | tee -a "$LOG"
echo "   >>> Service & Port"  | tee -a "$LOG"
echo "   - OpenSSH                  : 22"  | tee -a "$LOG"
echo "   - SSH Websocket            : 80" | tee -a "$LOG"
echo "   - SSH SSL Websocket        : 443" | tee -a "$LOG"
echo "   - Stunnel4                 : 222, 777" | tee -a "$LOG"
echo "   - Dropbear                 : 109, 143" | tee -a "$LOG"
echo "   - Badvpn                   : 7100-7900" | tee -a "$LOG"
echo "   - Nginx                    : 81" | tee -a "$LOG"
echo "   - Vmess WS TLS             : 443" | tee -a "$LOG"
echo "   - Vless WS TLS             : 443" | tee -a "$LOG"
echo "   - Trojan WS TLS            : 443" | tee -a "$LOG"
echo "   - Shadowsocks WS TLS       : 443" | tee -a "$LOG"
echo "   - Vmess WS none TLS        : 80" | tee -a "$LOG"
echo "   - Vless WS none TLS        : 80" | tee -a "$LOG"
echo "   - Trojan WS none TLS       : 80" | tee -a "$LOG"
echo "   - Shadowsocks WS none TLS  : 80" | tee -a "$LOG"
echo "   - Vmess gRPC               : 443" | tee -a "$LOG"
echo "   - Vless gRPC               : 443" | tee -a "$LOG"
echo "   - Trojan gRPC              : 443" | tee -a "$LOG"
echo "   - Shadowsocks gRPC         : 443" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "=============================Contact==============================" | tee -a "$LOG"
echo "---------------------------t.me/givpn-----------------------------" | tee -a "$LOG"
echo "==================================================================" | tee -a "$LOG"

# -----------------------------
# CLEAN UP TEMP FILES
# -----------------------------
run_with_progress "rm -f /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh /root/scripts/cf" "[CLEAN] Removing temp files"

# -----------------------------
# FINISHED
# -----------------------------
echo -e "\n\033[0;32mAll installations completed!\033[0m"
echo "Check installed service ports in $LOG"
