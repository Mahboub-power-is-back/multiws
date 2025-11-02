#!/bin/bash
# =============================
# MAHBOUB INSTALLATION SCRIPT
# =============================

# ----------------------------- COLORS -----------------------------
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
BBlue='\e[1;34m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
NC='\e[0m'

purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

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
    local spin=('|' '/' '-' '\\')
    local i=0
    printf "%-40s " "$msg"
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%-40s [%s]" "$msg" "${spin[i]}"
        sleep 0.1
        ((i = (i + 1) % 4))
    done
    
    wait "$pid"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r%-40s [\033[32mOK\033[0m]\n" "$msg"
    else
        printf "\r%-40s [\033[31mFAIL\033[0m]\n" "$msg"
        return 1
    fi
}

run_with_spinner() {
    local cmd="$1"
    local msg="$2"
    
    # Run command in background
    eval "$cmd" &>/root/lastlog.txt &
    local pid=$!
    
    run_spinner "$pid" "$msg"
    return $?
}

# ----------------------------- PROGRESS BAR -----------------------------
progress_bar() {
    local msg="$1"
    printf "%-40s [" "$msg"
    for i in {1..20}; do 
        printf "█"
        sleep 0.03
    done
    printf "] \033[32mOK\033[0m\n"
}

# ----------------------------- CHECK ROOT -----------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}[ERROR] This script must be run as root${NC}"
        exit 1
    fi
}

# ----------------------------- CHECK OS -----------------------------
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${red}[ERROR] Cannot detect operating system${NC}"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo -e "${red}[ERROR] This script only supports Ubuntu and Debian${NC}"
        exit 1
    fi
}

# ----------------------------- START -----------------------------
clear
print_logo
sleep 1

# Check prerequisites
check_root
check_os

LOG="/root/log-install.txt"
> "$LOG"

mkdir -p /etc/xray /etc/v2ray

# ----------------------------- DOMAIN MENU -----------------------------
echo -e "${BBlue}================ SETUP DOMAIN VPS ================${NC}"
echo -e "${BYellow}1. Random Cloudflare Subdomain${NC}"
echo -e "${BYellow}2. Enter Your Own Domain${NC}"
read -rp "Choose 1 or 2: " dns

if [ "$dns" == "1" ]; then
    run_with_spinner "wget -q -O /root/cf https://raw.githubusercontent.com/givpn/AutoScriptXray/master/ssh/cf && chmod +x /root/cf && bash /root/cf" "[DNS] Generating Domain"
    if [ -f /root/scdomain ] && [ -s /root/scdomain ]; then
        dom=$(cat /root/scdomain)
        echo -e "${green}[SUCCESS] Domain generated: $dom${NC}"
    else
        echo -e "${red}[ERROR] Domain generation failed!${NC}"
        echo -e "${yellow}[INFO] Trying alternative domain source...${NC}"
        
        # Try alternative source
        run_with_spinner "wget -q -O /root/cf2 https://raw.githubusercontent.com/fisabiliyusri/Mantap/main/ssh/cf.sh && chmod +x /root/cf2 && bash /root/cf2" "[DNS] Alternative Domain Generation"
        
        if [ -f /root/domain ] && [ -s /root/domain ]; then
            dom=$(cat /root/domain)
            echo -e "${green}[SUCCESS] Domain generated: $dom${NC}"
        else
            echo -e "${red}[ERROR] All domain generation methods failed!${NC}"
            echo -e "${yellow}[INFO] Please use option 2 to enter your own domain${NC}"
            exit 1
        fi
    fi
elif [ "$dns" == "2" ]; then
    read -rp "Enter your domain: " dom
    if [ -z "$dom" ]; then
        echo -e "${red}[ERROR] Domain cannot be empty!${NC}"
        exit 1
    fi
    
    # Basic domain validation
    if [[ ! "$dom" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${red}[ERROR] Invalid domain format!${NC}"
        exit 1
    fi
    echo -e "${green}[SUCCESS] Domain set to: $dom${NC}"
else
    echo -e "${red}[ERROR] Invalid choice!${NC}"
    exit 1
fi

# ----------------------------- SAVE DOMAIN -----------------------------
progress_bar "[DNS] Saving Domain"
for f in /etc/xray/scdomain /etc/xray/domain /etc/v2ray/domain /root/scdomain /root/domain /var/lib/ipvps.conf; do
    echo "$dom" > "$f"
done

# ----------------------------- SYSTEM UPDATE -----------------------------
progress_bar "[SYS] Updating System"
apt update -y &>/dev/null
apt upgrade -y &>/dev/null

# ----------------------------- DEPENDENCIES -----------------------------
run_with_spinner "apt install -y git curl wget python3 dos2unix bc net-tools" "[SYS] Installing Dependencies"

# ----------------------------- INSTALL SERVICES -----------------------------
echo -e "${BBlue}================ INSTALLING SERVICES ================${NC}"

# Install SSH WebSocket
if run_with_spinner "wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"; then
    echo -e "${green}[SUCCESS] SSH WebSocket installed${NC}"
else
    echo -e "${yellow}[WARNING] SSH WebSocket installation failed, continuing...${NC}"
fi

# Install Xray
if run_with_spinner "wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"; then
    echo -e "${green}[SUCCESS] Xray installed${NC}"
else
    echo -e "${yellow}[WARNING] Xray installation failed, trying alternative...${NC}"
    # Try alternative Xray source
    run_with_spinner "wget -q https://raw.githubusercontent.com/fisabiliyusri/Mantap/main/xray/ins-xray.sh -O /root/ins-xray-alt.sh && chmod +x /root/ins-xray-alt.sh && bash /root/ins-xray-alt.sh" "[XRAY] Alternative Xray Installation"
fi

# Install SSHWS
if run_with_spinner "wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[SSHWS] Installing SSHWS"; then
    echo -e "${green}[SUCCESS] SSHWS installed${NC}"
else
    echo -e "${yellow}[WARNING] SSHWS installation failed, continuing...${NC}"
fi

# ----------------------------- CLEAN -----------------------------
progress_bar "[CLEAN] Cleanup Files"
rm -f /root/ins-xray.sh /root/ssh-vpn.sh /root/insshws.sh /root/cf /root/cf2 /root/ins-xray-alt.sh &>/dev/null

# ----------------------------- FINAL CHECK -----------------------------
progress_bar "[FINAL] Final Configuration"

# Check if services are running
echo -e "${BBlue}================ SERVICE STATUS ================${NC}"
services=("nginx" "ssh" "xray" "v2ray")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "${green}✓ $service is running${NC}"
    else
        echo -e "${red}✗ $service is not running${NC}"
    fi
done

# ----------------------------- SERVICES & PORTS -----------------------------
{
echo ""
echo "==================== SERVICE & PORT ===================="
echo "OpenSSH                  : 22"
echo "SSH Websocket            : 80"
echo "SSH SSL Websocket        : 443"
echo "Stunnel4                 : 222, 777"
echo "Dropbear                 : 109, 143"
echo "Badvpn                   : 7100-7900"
echo "Nginx                    : 81"
echo "Vmess WS TLS             : 443"
echo "Vless WS TLS             : 443"
echo "Trojan WS TLS            : 443"
echo "Shadowsocks WS TLS       : 443"
echo "Vmess WS none TLS        : 80"
echo "Vless WS none TLS        : 80"
echo "Trojan WS none TLS       : 80"
echo "Shadowsocks WS none TLS  : 80"
echo "Vmess gRPC               : 443"
echo "Vless gRPC               : 443"
echo "Trojan gRPC              : 443"
echo "Shadowsocks gRPC         : 443"
echo "======================================================="
echo "Domain                   : $dom"
echo "Installation Log         : $LOG"
} | tee -a "$LOG"

# ----------------------------- DONE -----------------------------
echo -e "\n${BGreen}✅ INSTALLATION COMPLETED!${NC}"
echo -e "${BBlue}===============================================${NC}"
echo -e "${green}Your domain: $dom${NC}"
echo -e "${green}Log file: $LOG${NC}"
echo -e "${yellow}Please reboot your server after installation${NC}"
echo -e "${BBlue}===============================================${NC}"
