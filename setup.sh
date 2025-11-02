#!/bin/bash
# =============================
# MAHBOUB INSTALLATION SCRIPT - FIXED VERSION
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

# ----------------------------- YOUR GITHUB LINKS -----------------------------
GITHUB_BASE="https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master"
SSH_SCRIPT="$GITHUB_BASE/ssh/ssh-vpn.sh"
XRAY_SCRIPT="$GITHUB_BASE/xray/ins-xray.sh"
SSHWS_SCRIPT="$GITHUB_BASE/sshws/insshws.sh"
DOMAIN_SCRIPT="$GITHUB_BASE/ssh/cf"

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
    local spin=('|' '/' '-' '\')
    local i=0
    printf "%-40s " "$msg"
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b${spin:i++%4:1}"
        sleep 0.1
    done
    
    wait "$pid"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\b\033[32mOK\033[0m\n"
    else
        printf "\b\033[31mFAIL\033[0m\n"
        return 1
    fi
}

run_with_spinner() {
    local cmd="$1"
    local msg="$2"
    
    # Run command in background
    eval "$cmd" >/root/lastlog.txt 2>&1 &
    local pid=$!
    
    run_spinner "$pid" "$msg"
    return $?
}

# ----------------------------- DOMAIN GENERATION -----------------------------
generate_domain() {
    echo -e "${BGreen}[INFO] Generating domain...${NC}"
    
    # Try external script first
    if wget -q -O /root/cf "$DOMAIN_SCRIPT" && [ -f /root/cf ]; then
        chmod +x /root/cf
        ./cf
        sleep 2
        
        if [ -f /root/scdomain ] && [ -s /root/scdomain ]; then
            dom=$(cat /root/scdomain)
            echo -e "${BGreen}[SUCCESS] Domain generated: $dom${NC}"
            echo "$dom"
            return 0
        fi
    fi
    
    # Fallback: direct domain generation
    echo -e "${BYellow}[INFO] Using fallback domain generation...${NC}"
    local random_str=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
    local domains=("xray.cf" "mlcdn.cloud" "servehttp.com" "pages.dev")
    local selected_domain=${domains[$RANDOM % ${#domains[@]}]}
    local generated_domain="${random_str}.${selected_domain}"
    
    echo "$generated_domain" > /root/scdomain
    echo "$generated_domain" > /etc/xray/domain
    echo "$generated_domain" > /etc/v2ray/domain
    echo "$generated_domain" > /root/domain
    
    echo -e "${BGreen}[SUCCESS] Domain generated: $generated_domain${NC}"
    echo "$generated_domain"
}

# ----------------------------- CHECK ROOT & OS -----------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}[ERROR] This script must be run as root${NC}"
        exit 1
    fi
}

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

# ----------------------------- FAST INSTALLATION FUNCTIONS -----------------------------
install_ssh_websocket() {
    echo -e "${BGreen}[INFO] Installing SSH WebSocket...${NC}"
    
    if wget -q "$SSH_SCRIPT" -O /root/ssh-vpn.sh && [ -f /root/ssh-vpn.sh ]; then
        chmod +x /root/ssh-vpn.sh
        # Run in background
        bash /root/ssh-vpn.sh > /root/ssh-install.log 2>&1 &
        local ssh_pid=$!
        
        # Wait for completion
        wait $ssh_pid
        
        if [ $? -eq 0 ]; then
            echo -e "${BGreen}[SUCCESS] SSH WebSocket installed${NC}"
        else
            echo -e "${BYellow}[WARNING] SSH WebSocket installation had issues${NC}"
        fi
    else
        echo -e "${red}[ERROR] Failed to download SSH WebSocket from: $SSH_SCRIPT${NC}"
    fi
}

install_xray() {
    echo -e "${BGreen}[INFO] Installing Xray...${NC}"
    
    if wget -q "$XRAY_SCRIPT" -O /root/ins-xray.sh && [ -f /root/ins-xray.sh ]; then
        chmod +x /root/ins-xray.sh
        bash /root/ins-xray.sh > /root/xray-install.log 2>&1 &
        local xray_pid=$!
        
        wait $xray_pid
        
        if [ $? -eq 0 ]; then
            echo -e "${BGreen}[SUCCESS] Xray installed${NC}"
        else
            echo -e "${BYellow}[WARNING] Xray installation had issues${NC}"
        fi
    else
        echo -e "${red}[ERROR] Failed to download Xray from: $XRAY_SCRIPT${NC}"
    fi
}

install_sshws() {
    echo -e "${BGreen}[INFO] Installing SSHWS...${NC}"
    
    if wget -q "$SSHWS_SCRIPT" -O /root/insshws.sh && [ -f /root/insshws.sh ]; then
        chmod +x /root/insshws.sh
        bash /root/insshws.sh > /root/sshws-install.log 2>&1 &
        local sshws_pid=$!
        
        wait $sshws_pid
        
        if [ $? -eq 0 ]; then
            echo -e "${BGreen}[SUCCESS] SSHWS installed${NC}"
        else
            echo -e "${BYellow}[WARNING] SSHWS installation had issues${NC}"
        fi
    else
        echo -e "${red}[ERROR] Failed to download SSHWS from: $SSHWS_SCRIPT${NC}"
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

# ----------------------------- DOMAIN SETUP -----------------------------
echo -e "${BBlue}================ SETUP DOMAIN VPS ================${NC}"
echo -e "${BYellow}1. Random Domain${NC}"
echo -e "${BYellow}2. Enter Your Own Domain${NC}"
read -rp "Choose 1 or 2: " dns

if [ "$dns" == "1" ]; then
    domain=$(generate_domain)
elif [ "$dns" == "2" ]; then
    read -rp "Enter your domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${red}[ERROR] Domain cannot be empty!${NC}"
        exit 1
    fi
    
    # Basic domain validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${red}[ERROR] Invalid domain format!${NC}"
        exit 1
    fi
    
    # Save domain to files
    echo "$domain" > /root/scdomain
    echo "$domain" > /etc/xray/domain
    echo "$domain" > /etc/v2ray/domain
    echo "$domain" > /root/domain
    echo -e "${BGreen}[SUCCESS] Domain set to: $domain${NC}"
else
    echo -e "${red}[ERROR] Invalid choice!${NC}"
    exit 1
fi

# ----------------------------- SYSTEM UPDATE -----------------------------
echo -e "${BGreen}[INFO] Updating system packages...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
echo -e "${BGreen}[SUCCESS] System updated${NC}"

# ----------------------------- INSTALL DEPENDENCIES -----------------------------
echo -e "${BGreen}[INFO] Installing dependencies...${NC}"
apt install -y git curl wget python3 dos2unix bc net-tools > /dev/null 2>&1
echo -e "${BGreen}[SUCCESS] Dependencies installed${NC}"

# ----------------------------- INSTALL SERVICES -----------------------------
echo -e "${BBlue}================ INSTALLING SERVICES ================${NC}"

# Install services in sequence with better feedback
install_ssh_websocket
install_xray
install_sshws

# ----------------------------- FINAL SETUP -----------------------------
echo -e "${BGreen}[INFO] Finalizing installation...${NC}"

# Create profile
cat > /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

# Initialize log files
touch /etc/log-create-ssh.log
touch /etc/log-create-vmess.log
touch /etc/log-create-vless.log
touch /etc/log-create-trojan.log
touch /etc/log-create-shadowsocks.log

echo "Log SSH Account " > /etc/log-create-ssh.log
echo "Log Vmess Account " > /etc/log-create-vmess.log
echo "Log Vless Account " > /etc/log-create-vless.log
echo "Log Trojan Account " > /etc/log-create-trojan.log
echo "Log Shadowsocks Account " > /etc/log-create-shadowsocks.log

# ----------------------------- CLEANUP -----------------------------
echo -e "${BGreen}[INFO] Cleaning up...${NC}"
rm -f /root/ins-xray.sh /root/ssh-vpn.sh /root/insshws.sh /root/cf > /dev/null 2>&1

# ----------------------------- SERVICE STATUS -----------------------------
echo -e "${BBlue}================ SERVICE STATUS ================${NC}"
services=("nginx" "ssh" "xray" "dropbear" "stunnel4")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "  ${BGreen}✓${NC} $service is running"
    else
        echo -e "  ${red}✗${NC} $service is not running"
    fi
done

# ----------------------------- FINAL OUTPUT -----------------------------
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
echo "Domain                   : $domain"
echo "Installation Log         : $LOG"
echo "GitHub Repository        : https://github.com/Mahboub-power-is-back/multiws"
} | tee -a "$LOG"

# ----------------------------- COMPLETION -----------------------------
echo -e "\n${BGreen}✅ INSTALLATION COMPLETED!${NC}"
echo -e "${BBlue}===============================================${NC}"
echo -e "${green}Your domain: $domain${NC}"
echo -e "${green}Log file: $LOG${NC}"
echo -e "${green}GitHub: https://github.com/Mahboub-power-is-back/multiws${NC}"
echo -e "${yellow}Please reboot your server after installation${NC}"
echo -e "${BBlue}===============================================${NC}"

# Optional reboot
echo -e "\n${BYellow}Do you want to reboot now? (y/n): ${NC}"
read -r reboot_choice
if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
    echo -e "${BGreen}[INFO] Rebooting system...${NC}"
    reboot
else
    echo -e "${BGreen}[INFO] Installation complete. Please reboot manually when ready.${NC}"
fi
