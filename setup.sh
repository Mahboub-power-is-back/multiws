#!/bin/bash
# =============================
# MULTIPLUS INSTALLATION SCRIPT - FIXED VERSION
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
 __  __   _   _ _   _ ____  _      ____ _     _____ ____  
|  \/  | | | | | | | |  _ \| |    / ___| |   | ____/ ___| 
| |\/| | | | | | | | | |_) | |   | |   | |   |  _| \___ \ 
| |  | | | |_| | |_| |  __/| |___| |___| |___| |___ ___) |
|_|  |_|  \___/ \___/|_|   |_____|\____|_____|_____|____/ 
==================================================================\033[0m
EOF
}

# ----------------------------- SIMPLE PROGRESS -----------------------------
show_progress() {
    local msg="$1"
    printf "%-40s" "$msg"
}

show_success() {
    printf "\033[32mOK\033[0m\n"
}

show_fail() {
    printf "\033[31mFAIL\033[0m\n"
}

# ----------------------------- DOMAIN GENERATION -----------------------------
generate_domain() {
    echo -e "${BGreen}[INFO] Generating domain...${NC}"
    
    # Try to download and use the domain script
    show_progress "[DNS] Downloading domain script"
    if wget -q -O /root/cf "$DOMAIN_SCRIPT" && [ -f /root/cf ]; then
        show_success
        
        # Check if the file has content
        show_progress "[DNS] Setting up domain script"
        if [ -s /root/cf ]; then
            chmod +x /root/cf
            show_success
            
            show_progress "[DNS] Generating domain"
            # Run the domain script and capture output
            if ./cf > /root/domain-generation.log 2>&1; then
                # Check if domain was generated in any of the possible files
                if [ -f /root/domain ] && [ -s /root/domain ]; then
                    dom=$(cat /root/domain)
                    show_success
                    echo -e "${BGreen}[SUCCESS] Domain generated: $dom${NC}"
                    echo "$dom"
                    return 0
                elif [ -f /root/scdomain ] && [ -s /root/scdomain ]; then
                    dom=$(cat /root/scdomain)
                    show_success
                    echo -e "${BGreen}[SUCCESS] Domain generated: $dom${NC}"
                    echo "$dom"
                    return 0
                else
                    show_fail
                    echo -e "${BYellow}[WARNING] Domain script ran but no domain file was created${NC}"
                    # Check the log for errors
                    if [ -f /root/domain-generation.log ]; then
                        echo -e "${BYellow}[DEBUG] Domain script output:${NC}"
                        tail -n 10 /root/domain-generation.log
                    fi
                fi
            else
                show_fail
                echo -e "${BYellow}[WARNING] Domain script execution failed${NC}"
                if [ -f /root/domain-generation.log ]; then
                    echo -e "${BYellow}[DEBUG] Domain script error:${NC}"
                    tail -n 10 /root/domain-generation.log
                fi
            fi
        else
            show_fail
            echo -e "${BYellow}[WARNING] Downloaded domain script is empty${NC}"
        fi
    else
        show_fail
        echo -e "${BYellow}[WARNING] Failed to download domain script from: $DOMAIN_SCRIPT${NC}"
    fi
    
    # Fallback: direct domain generation
    echo -e "${BYellow}[INFO] Using fallback domain generation...${NC}"
    show_progress "[DNS] Generating random domain"
    
    # Generate random string
    local random_str=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
    local generated_domain="asx-${random_str}.mahboubvps.site"
    
    # Save domain to all required files
    echo "$generated_domain" > /root/scdomain
    echo "$generated_domain" > /etc/xray/domain
    echo "$generated_domain" > /etc/v2ray/domain
    echo "$generated_domain" > /root/domain
    echo "IP=$generated_domain" > /var/lib/ipvps.conf
    
    show_success
    echo -e "${BGreen}[SUCCESS] Fallback domain generated: $generated_domain${NC}"
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

# ----------------------------- INSTALLATION FUNCTIONS -----------------------------
download_and_install() {
    local url="$1"
    local filename="$2"
    local service_name="$3"
    
    show_progress "[$service_name] Downloading"
    if wget -q "$url" -O "/root/$filename" && [ -f "/root/$filename" ]; then
        show_success
        
        show_progress "[$service_name] Installing"
        chmod +x "/root/$filename"
        
        # Run the installation script
        if bash "/root/$filename" > "/root/${service_name}-install.log" 2>&1; then
            show_success
            echo -e "  ${BGreen}✓${NC} $service_name installed successfully"
            return 0
        else
            show_fail
            echo -e "  ${BYellow}⚠${NC} $service_name installation had issues"
            # Show last few lines of log for debugging
            if [ -f "/root/${service_name}-install.log" ]; then
                echo -e "  ${BYellow}[DEBUG] Last 5 lines of log:${NC}"
                tail -n 5 "/root/${service_name}-install.log"
            fi
            return 1
        fi
    else
        show_fail
        echo -e "  ${red}✗${NC} Failed to download $service_name from: $url"
        return 1
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

echo -e "${BGreen}[INFO] Starting installation...${NC}"

# ----------------------------- DOMAIN SETUP -----------------------------
echo -e "${BBlue}================ SETUP DOMAIN VPS ================${NC}"
echo -e "${BYellow}1. Random Domain (Cloudflare)${NC}"
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
    show_progress "[DNS] Saving domain"
    echo "$domain" > /root/scdomain
    echo "$domain" > /etc/xray/domain
    echo "$domain" > /etc/v2ray/domain
    echo "$domain" > /root/domain
    echo "IP=$domain" > /var/lib/ipvps.conf
    show_success
    echo -e "${BGreen}[SUCCESS] Domain set to: $domain${NC}"
else
    echo -e "${red}[ERROR] Invalid choice!${NC}"
    exit 1
fi

# ----------------------------- SYSTEM UPDATE -----------------------------
show_progress "[SYS] Updating system"
if apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1; then
    show_success
else
    show_fail
    echo -e "${BYellow}[WARNING] System update had issues, but continuing...${NC}"
fi

# ----------------------------- INSTALL DEPENDENCIES -----------------------------
show_progress "[SYS] Installing dependencies"
if apt install -y git curl wget python3 dos2unix bc net-tools jq > /dev/null 2>&1; then
    show_success
else
    show_fail
    echo -e "${BYellow}[WARNING] Some dependencies failed to install, but continuing...${NC}"
fi

# ----------------------------- INSTALL SERVICES -----------------------------
echo -e "${BBlue}================ INSTALLING SERVICES ================${NC}"

# Install services in sequence
download_and_install "$SSH_SCRIPT" "ssh-vpn.sh" "SSH"
download_and_install "$XRAY_SCRIPT" "ins-xray.sh" "XRAY" 
download_and_install "$SSHWS_SCRIPT" "insshws.sh" "SSHWS"

# ----------------------------- FINAL SETUP -----------------------------
echo -e "${BGreen}[INFO] Finalizing installation...${NC}"

# Create profile
show_progress "[SYS] Creating profile"
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
show_success

# Initialize log files
show_progress "[SYS] Creating log files"
mkdir -p /etc/xray /etc/v2ray
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
show_success

# ----------------------------- CLEANUP -----------------------------
show_progress "[SYS] Cleaning up"
rm -f /root/ins-xray.sh /root/ssh-vpn.sh /root/insshws.sh /root/cf /root/domain-generation.log > /dev/null 2>&1
show_success

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
echo
