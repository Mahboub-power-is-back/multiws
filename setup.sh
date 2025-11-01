#!/bin/bash

# -----------------------------
# MAHBOUB LOGO
# -----------------------------
print_logo() {
cat << "EOF"
==================================================================
 __  __       _    _     _    _    ____  ____  ____  
|  \/  | __ _| | _| |__ | | _| |  |  _ \/ ___|| __ ) 
| |\/| |/ _` | |/ / '_ \| |/ / |  | | | \___ \|  _ \
| |  | | (_| |   <| | | |   <| |__| |_| |___) | |_) |
|_|  |_|\__,_|_|\_\_| |_|_|\_\____|____/|____/|____/ 
                                                      
==================================================================
EOF
}

# -----------------------------
# BLOCK PROGRESS BAR FUNCTION
# -----------------------------
progress_bar() {
    local msg="$1"
    local duration=${2:-2}   # Default duration 2 seconds
    local steps=24           # Number of blocks
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
    progress_bar "$msg" 1
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
# SYSTEM UPDATE & DEPENDENCIES
# -----------------------------
run_with_progress "apt update -y && apt upgrade -y" "Updating system"
run_with_progress "apt install -y git curl wget python dos2unix" "Installing dependencies"

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
# Domain Setup
# -----------------------------
read -rp "Enter your domain (or leave empty for random): " dom
if [ -z "$dom" ]; then
    dom="random-domain.com"
fi
echo "IP=$dom" > /var/lib/ipvps.conf
echo "$dom" > /root/scdomain
echo "$dom" > /etc/xray/scdomain
echo "$dom" > /etc/xray/domain
echo "$dom" > /etc/v2ray/domain
echo "$dom" > /root/domain

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
- UDPCUSTOM                : 1-65535
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
