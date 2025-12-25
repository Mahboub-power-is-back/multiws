#!/bin/bash

# ------------------------------
# Color codes and styling
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# ------------------------------
# Progress bar functions
# ------------------------------
show_progress() {
    local duration=$1
    local step=$2
    local width=50
    local increment=$((100 / width))
    local percent=0
    local filled=0
    
    echo -ne "${BLUE}[${NC}"
    for ((i=0; i<width; i++)); do
        echo -ne " "
    done
    echo -ne "${BLUE}]${NC} 0%\r"
    
    while [ $percent -lt 100 ]; do
        sleep $(echo "scale=3; $duration/$width" | bc)
        filled=$((filled + 1))
        percent=$((percent + increment))
        if [ $percent -gt 100 ]; then
            percent=100
        fi
        
        echo -ne "${BLUE}[${NC}${GREEN}"
        for ((i=0; i<filled; i++)); do
            echo -ne "█"
        done
        echo -ne "${NC}"
        for ((i=filled; i<width; i++)); do
            echo -ne " "
        done
        echo -ne "${BLUE}]${NC} ${percent}% ${step}\r"
    done
    echo -e "\n"
}

spin_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local text=$2
    
    echo -ne "  ${text}... "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -e "${GREEN}✅${NC}"
}

run_with_progress() {
    local cmd=$1
    local text=$2
    
    echo -ne "  ${text}..."
    $cmd > /dev/null 2>&1 &
    local pid=$!
    
    # Show spinner while command runs
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -e "${GREEN}✅${NC}"
}

# ------------------------------
# Header and UI functions
# ------------------------------
print_header() {
    clear
    echo -e "${BLUE}"
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│           ${CYAN}🛠️  PROFESSIONAL VPS INSTALLER${BLUE}              │"
    echo "└──────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${YELLOW}${BOLD}▶${NC} ${CYAN}${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}${BOLD}✗${NC} ${RED}$1${NC}"
}

# ------------------------------
# Root check
# ------------------------------
print_header
echo -e "${BLUE}${BOLD}Initializing system check...${NC}\n"

if [ "${EUID:-0}" -ne 0 ]; then
    print_error "This script must be run as root!"
    echo -e "${DIM}Use: sudo bash setup.sh${NC}"
    exit 1
fi

print_success "Root privileges confirmed"

# ------------------------------
# Initial System Update
# ------------------------------
print_step "Step 1: System Preparation"
run_with_progress "apt update -y" "Updating package lists"
show_progress 2 "Installing dependencies (jq, curl, wget)"
apt install -y jq curl wget >/dev/null 2>&1

# ------------------------------
# Cloudflare API Info
# ------------------------------
DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

# ------------------------------
# Create directories
# ------------------------------
print_step "Step 2: Creating directories structure"
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain
print_success "Directory structure created"

# ------------------------------
# Domain Selection Menu
# ------------------------------
print_step "Step 3: Domain Configuration"
echo -e "${BLUE}"
echo "┌──────────────────────────────────────────────────────────┐"
echo "│              ${CYAN}DOMAIN CONFIGURATION MENU${BLUE}                   │"
echo "└──────────────────────────────────────────────────────────┘"
echo -e "${NC}"
echo -e "  ${YELLOW}[1]${NC} Random A + NS (Cloudflare)"
echo -e "  ${YELLOW}[2]${NC} Random A only (Cloudflare)"
echo -e "  ${YELLOW}[3]${NC} Your domain A only"
echo -e "  ${YELLOW}[4]${NC} Your domain A + NS"

read -rp "  Select option (1/2/3/4): " dns

IP=$(curl -s ipv4.icanhazip.com)

echo -ne "\n  Configuring domain..."
case "$dns" in
  1)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"
    
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  3)
    read -rp "  Enter your domain (A only): " dom
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    SUB="$dom"
    ;;
  4)
    read -rp "  Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"
    
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  *)
    print_error "Invalid selection"
    exit 1
    ;;
esac

echo -e "${GREEN}✅${NC}"
print_success "Domain setup completed"
echo -e "  ${DIM}A Record → ${BOLD}$SUB${DIM} → $IP${NC}"
[[ ! -z "$NS_SUB" ]] && echo -e "  ${DIM}NS Record → ${BOLD}$NS_SUB${DIM} → $SUB${NC}"

# ------------------------------
# Install Services
# ------------------------------
print_step "Step 4: Installing Services"
echo -e "${DIM}This may take several minutes. Please wait...${NC}\n"

echo -e "${YELLOW}Installing SSH/VPN Service...${NC}"
show_progress 5 "Downloading and configuring SSH/VPN"
wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh"
chmod +x /root/ssh-vpn.sh
bash /root/ssh-vpn.sh >/dev/null 2>&1
print_success "SSH/VPN installed"

echo -e "\n${YELLOW}Installing XRay Service...${NC}"
show_progress 8 "Downloading and configuring XRay"
wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh"
chmod +x /root/ins-xray.sh
bash /root/ins-xray.sh >/dev/null 2>&1
print_success "XRay installed"

echo -e "\n${YELLOW}Installing SSH Websocket...${NC}"
show_progress 4 "Downloading and configuring SSH Websocket"
wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh"
chmod +x /root/insshws.sh
bash /root/insshws.sh >/dev/null 2>&1
print_success "SSH Websocket installed"

# ------------------------------
# Install DNSTT Service
# ------------------------------
print_step "Step 5: Installing DNSTT Service"
if [ -f /root/nsdomain ]; then
    DnsNS=$(cat /root/nsdomain)
    echo -e "  ${DIM}Using NS domain: ${BOLD}$DnsNS${NC}"
else
    print_error "NS domain not found! Skipping DNSTT."
    DnsNS=""
fi

if [ ! -z "$DnsNS" ]; then
    PORT1=443
    show_progress 3 "Downloading DNSTT server binary"
    wget -q -c https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/refs/heads/main/dnstt-server -O /usr/local/bin/dnstt-server
    chmod +x /usr/local/bin/dnstt-server
    
    echo -ne "  Configuring DNSTT service..."
    cat <<EOF > /etc/systemd/system/dnstt-service.service
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/sbin/iptables -A INPUT -p tcp --dport 5300 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey e35bb50094b4d06a17a7606ae724db082398a4cf86ad79bcdcf890386eb65a88 $DnsNS 127.0.0.1:$PORT1
StandardOutput=append:/var/log/dnstt.log
StandardError=append:/var/log/dnstt.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl start dnstt-service >/dev/null 2>&1
    systemctl enable dnstt-service >/dev/null 2>&1
    echo -e "${GREEN}✅${NC}"
    print_success "DNSTT server started on TCP/UDP port $PORT1"
fi

# ------------------------------
# Setup .profile
# ------------------------------
print_step "Step 6: Final Configuration"
run_with_progress "echo 'if [ \"\$BASH\" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu' > /root/.profile" "Configuring user profile"

chmod 644 /root/.profile

# ------------------------------
# Log services & ports
# ------------------------------
LOG="/root/log-install.txt"
{
echo ""
printf "┌───────────────────────────────────────────────────────────────┐\n"
printf "│                         SERVICE & PORTS                        │\n"
printf "└───────────────────────────────────────────────────────────────┘\n"
echo "   - OpenSSH                  : 22"
echo "   - OpenVPN                  : 1194"
echo "   - SSH Websocket            : 80"
echo "   - SSH SSL Websocket        : 443"
echo "   - OVPN Websocket           : 80"
echo "   - OVPN SSL Websocket       : 443"
echo "   - Stunnel4                 : 222, 777"
echo "   - Dropbear                 : 109, 143"
echo "   - UDP CUSTOM               : 1-65535"
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
echo "   - DNSTT Server             : 443"
echo ""
} >>"$LOG"

# ------------------------------
# Final Permissions and Cleanup
# ------------------------------
run_with_progress "chmod 644 /etc/systemd/system/ws-stunnel.service /etc/systemd/system/ws-ovpn.service /etc/systemd/system/ws-dropbear.service /etc/systemd/system/xray.service" "Setting up permissions"
run_with_progress "history -c" "Clearing history"

# ------------------------------
# Installation Complete
# ------------------------------
print_header
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║         🎉 INSTALLATION COMPLETE! 🎉               ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}${BOLD}Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Domain configured: ${BOLD}$SUB${NC}"
echo -e "  ${GREEN}✓${NC} IP Address: ${BOLD}$IP${NC}"
echo -e "  ${GREEN}✓${NC} SSH/VPN Service installed"
echo -e "  ${GREEN}✓${NC} XRay Service installed"
echo -e "  ${GREEN}✓${NC} SSH Websocket installed"
[[ ! -z "$DnsNS" ]] && echo -e "  ${GREEN}✓${NC} DNSTT Service installed on port 443"

echo -e "\n${YELLOW}${BOLD}Important:${NC}"
echo -e "  • Installation log: ${BOLD}/root/log-install.txt${NC}"
echo -e "  • System will reboot in 10 seconds..."
echo -e "  • After reboot, type '${BOLD}menu${NC}' to access the control panel\n"

echo -e "${DIM}Finalizing setup and preparing for reboot...${NC}"
show_progress 10 "Final system configuration"

rm -f /root/setup.sh
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service

reboot
