#!/bin/bash

# -----------------------------
# RED MAHBOUB LOGO
# -----------------------------
print_logo() {
echo -e "\e[31m
==================================================================
 __  __       _    _     _    _    ____  ____  ____  
|  \/  | __ _| | _| |__ | | _| |  |  _ \/ ___|| __ ) 
| |\/| |/ _\` | |/ / '_ \| |/ / |  | | | \___ \|  _ \\
| |  | | (_| |   <| | | |   <| |__| |_| |___) | |_) |
|_|  |_|\__,_|_|\_\_| |_|_|\_\____|____/|____/|____/ 
                                                      
==================================================================
\e[0m"
}

# -----------------------------
# RUN COMMAND WITH REAL-TIME PROGRESS
# -----------------------------
run_cmd() {
    local cmd="$1"
    local msg="$2"
    printf "%s " "$msg"

    $cmd &>/dev/null &
    cmd_pid=$!

    while kill -0 $cmd_pid 2>/dev/null; do
        printf "█"
        sleep 0.08
    done

    wait $cmd_pid
    printf " OK\n"
}

# -----------------------------
# DOMAIN CONFIGURATION
# -----------------------------
configure_domain() {
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
    run_cmd "bash /root/scripts/cf" "[CF] Generating Domain"
    DOMAIN=$(cat /root/domain)
    ;;
  2)
    read -rp "Enter your domain: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "[ERROR] Empty domain. Exiting."
        exit 1
    fi
    ;;
  *)
    echo "[ERROR] Invalid selection. Exiting."
    exit 1
    ;;
esac

# Save domain to configs
echo "IP=$DOMAIN" > /var/lib/ipvps.conf
echo "$DOMAIN" > /root/scdomain
echo "$DOMAIN" > /etc/xray/scdomain
echo "$DOMAIN" > /etc/xray/domain
echo "$DOMAIN" > /etc/v2ray/domain
echo "$DOMAIN" > /root/domain
}

# -----------------------------
# START SCRIPT
# -----------------------------
clear
print_logo
sleep 0.5

configure_domain

LOG="/root/log-install.txt"
> "$LOG"

# -----------------------------
# SYSTEM UPDATE & DEPENDENCIES
# -----------------------------
run_cmd "apt update -y && apt upgrade -y" "[SYS] Updating System"
run_cmd "apt install -y git curl wget python dos2unix" "[SYS] Installing Dependencies"

# -----------------------------
# INSTALL SSH, Xray, SSH-WS
# -----------------------------
run_cmd "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"
run_cmd "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"
run_cmd "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[WS] Installing SSH over WebSocket"

# -----------------------------
# CLEANUP TEMP FILES
# -----------------------------
run_cmd "rm -f /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh" "[CLEAN] Removing temporary files"

# -----------------------------
# LOG SERVICE PORTS
# -----------------------------
cat > "$LOG" << EOF
===================== SERVICES & PORTS =====================
Domain / Hostname : $DOMAIN
OpenSSH           : 22
SSH WebSocket     : 80
SSH SSL WebSocket : 443
Dropbear          : 109, 143
Stunnel4          : 222, 777
Badvpn            : 7100-7900
Nginx             : 81
Vmess WS TLS      : 443
Vless WS TLS      : 443
Trojan WS TLS     : 443
Shadowsocks WS TLS: 443
Vmess WS non TLS  : 80
Vless WS non TLS  : 80
Trojan WS non TLS : 80
Shadowsocks WS non TLS: 80
Vmess gRPC        : 443
Vless gRPC        : 443
Trojan gRPC       : 443
Shadowsocks gRPC  : 443
============================================================
EOF

# -----------------------------
# FINISHED
# -----------------------------
clear
print_logo
echo -e "\e[32mINSTALLATION COMPLETE!\e[0m"
echo "Service ports logged → $LOG"
echo -e "Domain Used → \e[32m$DOMAIN\e[0m"
