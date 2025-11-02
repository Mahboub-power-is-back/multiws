#!/bin/bash

# =============================
# MAHBOUB INSTALLATION SCRIPT
# =============================

# ----------------------------- LOGO -----------------------------
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

# ----------------------------- SPINNER -----------------------------
run_spinner() {
    local pid=$1
    local msg="$2"
    local spin='|/-\'
    printf "%-40s " "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:i++%4:1}"
        sleep 0.1
    done
    wait $pid
    [ $? -eq 0 ] && printf "\b\033[32mOK\033[0m\n" || { printf "\b\033[31mFAIL\033[0m\n"; exit 1; }
}

run_with_spinner() {
    bash -c "$1" &> /root/lastlog.txt &
    run_spinner $! "$2"
}

# ----------------------------- PROGRESS BAR -----------------------------
progress_bar() {
    printf "%-40s " "$1"
    for i in {1..20}; do printf "█"; sleep 0.05; done
    printf " \033[32mOK\033[0m\n"
}

# Start
clear
print_logo
sleep 1

LOG="/root/log-install.txt"
> "$LOG"

mkdir -p /etc/xray /etc/v2ray

# ----------------------------- DOMAIN MENU -----------------------------
echo "  [1] Random Cloudflare Subdomain"
echo "  [2] Enter Your Own Domain"
read -p "Select option (1/2): " dns

if [ "$dns" == "1" ]; then
    run_with_spinner "wget -q -O /root/cf https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/cf && chmod +x /root/cf && bash /root/cf" "[DNS] Generating Domain"
    dom=$(cat /root/scdomain)
else
    read -p "Enter Domain: " dom
fi

# ----------------------------- SAVE DOMAIN -----------------------------
for f in /etc/xray/scdomain /etc/xray/domain /etc/v2ray/domain /root/scdomain /root/domain /var/lib/ipvps.conf; do
    echo "$dom" > "$f"
done

# ----------------------------- SYSTEM UPDATE (FAST) -----------------------------
progress_bar "[SYS] Updating System"
apt update -y &>/dev/null
apt upgrade -y &>/dev/null

# ----------------------------- DEPENDENCIES -----------------------------
run_with_spinner "apt install -y git curl wget python3 dos2unix bc" "[SYS] Installing Dependencies"

# ----------------------------- INSTALL SERVICES -----------------------------
run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"

run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"

run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[SSHWS] Installing SSHWS"

# ----------------------------- CLEAN -----------------------------
run_with_spinner "rm -f /root/ins-xray.sh /root/ssh-vpn.sh /root/insshws.sh /root/cf" "[CLEAN] Cleanup"

# ----------------------------- DONE -----------------------------
echo -e "\n\033[1;32m✅ INSTALLATION COMPLETE!\033[0m"
echo "Your domain:  $dom"
echo "Log file: $LOG"
