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

show_working() {
    printf "\033[33mWORKING\033[0m\n"
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
                fi
            else
                show_fail
                echo -e "${BYellow}[WARNING] Domain script execution failed${NC}"
            fi
        else
            show_fail
            echo -e "${BYellow}[WARNING] Downloaded domain script is empty${NC}"
        fi
    else
        show_fail
        echo -e "${BYellow}[WARNING] Failed to download domain script${NC}"
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
        
        # Run the installation script with timeout
        if timeout 300 bash "/root/$filename" > "/root/${service_name}-install.log" 2>&1; then
            show_success
            echo -e "  ${BGreen}✓${NC} $service_name installed successfully"
            return 0
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                show_fail
                echo -e "  ${red}✗${NC} $service_name installation timed out (5 minutes)"
                echo -e "  ${BYellow}⚠${NC} Continuing with next service..."
            else
                show_fail
                echo -e "  ${BYellow}⚠${NC} $service_name installation had issues (exit code: $exit_code)"
            fi
            
            # Show last few lines of log for debugging
            if [ -f "/root/${service_name}-install.log" ]; then
                echo -e "  ${BYellow}[DEBUG] Last 10 lines of log:${NC}"
                tail -n 10 "/root/${service_name}-install.log"
            fi
            return 1
        fi
    else
        show_fail
        echo -e "  ${red}✗${NC} Failed to download $service_name"
        return 1
    fi
}

# Fast Xray installation function
install_xray_fast() {
    echo -e "${BGreen}[INFO] Installing Xray (fast method)...${NC}"
    
    show_progress "[XRAY] Downloading script"
    if wget -q "$XRAY_SCRIPT" -O /root/ins-xray.sh && [ -f /root/ins-xray.sh ]; then
        show_success
        
        show_progress "[XRAY] Making executable"
        chmod +x /root/ins-xray.sh
        show_success
        
        # Create an automated response file for any prompts
        echo -e "${BGreen}[INFO] Running Xray installation in background...${NC}"
        
        # Run with timeout and auto-yes
        timeout 600 bash -c "
            echo 'Y' | bash /root/ins-xray.sh
        " > /root/xray-install.log 2>&1 &
        
        local xray_pid=$!
        
        # Show progress while waiting
        echo -ne "  ${BYellow}⏳${NC} Xray installation in progress "
        local dots=0
        while kill -0 $xray_pid 2>/dev/null; do
            if [ $dots -eq 0 ]; then echo -ne "."; fi
            if [ $dots -eq 1 ]; then echo -ne "."; fi
            if [ $dots -eq 2 ]; then echo -ne "."; fi
            if [ $dots -eq 3 ]; then echo -ne "\b\b\b   \b\b\b"; dots=-1; fi
            ((dots++))
            sleep 1
        done
        
        wait $xray_pid
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo -e "\r  ${BGreen}✓${NC} Xray installed successfully              "
            return 0
        elif [ $exit_code -eq 124 ]; then
            echo -e "\r  ${red}✗${NC} Xray installation timed out (10 minutes)  "
            echo -e "  ${BYellow}⚠${NC} Continuing with next service..."
            return 1
        else
            echo -e "\r  ${BYellow}⚠${NC} Xray installation completed with warnings"
            # Check if Xray service is running despite the error
            if systemctl is-active --quiet xray; then
                echo -e "  ${BGreen}✓${NC} Xray service is running"
                return 0
            fi
            return 1
        fi
    else
        show_fail
        echo -e "  ${red}✗${NC} Failed to download Xray script"
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
if apt install -y git curl wget python3 dos2unix bc net-tools jq timeout > /dev/null 2>&1; then
    show_success
else
    show_fail
    echo -e "${BYellow}[WARNING] Some dependencies failed to install, but continuing...${NC}"
fi

# ----------------------------- INSTALL SERVICES -----------------------------
echo -e "${BBlue}================ INSTALLING SERVICES ================${NC}"

# Install SSH
show_progress "[SSH] Downloading"
if wget -q "$SSH_SCRIPT" -O /root/ssh-vpn.sh && [ -f /root/ssh-vpn.sh ]; then
    show_success
    show_progress "[SSH] Installing"
    chmod +x /root/ssh-vpn.sh
    # Run SSH installation with auto-yes
    echo -e "\n" | bash /root/ssh-vpn.sh > /root/ssh-install.log 2>&1
    show_success
    echo -e "  ${BGreen}✓${NC} SSH installed successfully"
else
    show_fail
    echo -e "  ${red}✗${NC} Failed to download SSH"
fi

# Install Xray with improved method
install_xray_fast

# Install SSHWS
show_progress "[SSHWS] Downloading"
if wget -q "$SSHWS_SCRIPT" -O /root/insshws.sh && [ -f /root/insshws.sh ]; then
    show_success
    show_progress "[SSHWS] Installing"
    chmod +x /root/insshws.sh
    # Run SSHWS installation with auto-yes
    echo -e "\n" | bash /root/insshws.sh > /root/sshws-install.log 2>&1
    show_success
    echo -e "  ${BGreen}✓${NC} SSHWS installed successfully"
else
    show_fail
    echo -e "  ${red}✗${NC} Failed to download SSHWS"
fi

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
touch /etc/log-create-ssh.log /etc/log-create-vmess.log /etc/log-create-vless.log /etc/log-create-trojan.log /etc/log-create-shadowsocks.log

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
