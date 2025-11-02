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
# SPINNER FUNCTION
# -----------------------------
run_spinner() {
    local pid=$1
    local msg="$2"
    local spin='|/-\'
    i=0
    printf "%-45s " "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spin:i%4:1}"
        sleep 0.1
        ((i++))
    done
    wait $pid
    rc=$?
    printf "\b"
    if [ $rc -eq 0 ]; then
        printf "\033[32mOK\033[0m\n"
    else
        printf "\033[31mFAIL\033[0m\n"
        tail -n 50 /root/lastlog.txt
        exit 1
    fi
}

# -----------------------------
# RUN COMMAND WITH SPINNER
# -----------------------------
run_with_spinner() {
    local cmd="$1"
    local msg="$2"
    bash -c "$cmd" &> /root/lastlog.txt &
    run_spinner $! "$msg"
}

# -----------------------------
# PROGRESS BAR FUNCTION (Optional)
# -----------------------------
progress_bar() {
    local msg="$1"
    local steps=24
    printf "%s " "$msg"
    for i in $(seq 1 $steps); do
        printf "█"
        sleep 0.03
    done
    printf " OK\n"
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
    run_with_spinner "wget -q -O /root/scripts/cf $CF_URL && dos2unix /root/scripts/cf && chmod +x /root/scripts/cf && bash /root/scripts/cf" "[DNS] Generating Cloudflare Domain"
    dom=$(cat /root/scdomain)
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
run_with_spinner "apt update -y && apt upgrade -y" "[SYS] Updating System"
run_with_spinner "apt install -y git curl wget python3 dos2unix bc" "[SYS] Installing Dependencies"

# -----------------------------
# INSTALL SERVICES
# -----------------------------
run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"
run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"
run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[SSHWS] Installing SSH over WebSocket"

# -----------------------------
# LOG SERVICE PORTS
# -----------------------------
{
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
echo "=============================Contact=============================="
echo "---------------------------t.me/givpn-----------------------------"
echo "=================================================================="
} | tee -a "$LOG"

# -----------------------------
# CLEAN UP TEMP FILES
# -----------------------------
run_with_spinner "rm -f /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh /root/scripts/cf" "[CLEAN] Removing temp files"

# -----------------------------
# FINISHED
# -----------------------------
echo -e "\n\033[0;32mAll installations completed!\033[0m"
echo "Check installed service ports in $LOG"
