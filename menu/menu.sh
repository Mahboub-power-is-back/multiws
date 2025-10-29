#!/bin/bash
# VARIABLE
domain=$(cat /etc/xray/domain)
uptime="$(uptime -p | cut -d " " -f 2-10)"
IPVPS=$(curl -s ifconfig.me)
LOC=$(curl -s ifconfig.co/country)
tram=$(free -m | awk 'NR==2 {print $2}')
uram=$(free -m | awk 'NR==2 {print $3}')
# COLOR
red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
purple='\e[1;35m'
cyan='\e[1;36m'
NC='\e[0m'
clear
echo -e "${cyan}╔═══════════════════════════════════════════════════╗
${NC}"
echo -e "${cyan}║${NC}                 ${yellow}★ VPS CONTROL PANEL ★
${NC}             ${cyan}║${NC}"
echo -e "${cyan}╚═══════════════════════════════════════════════════╝
${NC}"
echo ""
echo -e "${green}SYSTEM INFORMATION${NC}"
echo -e "${purple}───────────────────────────────────────────────────
─${NC}"
echo -e "${yellow}• Uptime       :${NC} $uptime"
echo -e "${yellow}• IP Address   :${NC} $IPVPS"
echo -e "${yellow}• Country      :${NC} $LOC"
echo -e "${yellow}• Domain       :${NC} $domain"
echo -e "${yellow}• RAM Usage    :${NC} $uram MB / $tram MB"
echo -e "${purple}───────────────────────────────────────────────────
─${NC}"
echo ""
echo -e "${green}SERVICE MENU${NC}"
echo -e "${cyan}╔═══════════════════════════════════════════════╗${NC
}"
echo -e "${cyan}║${NC}  ${yellow}[1] SSH                 ${cyan}[5] S
HADOWSOCKS WS${NC}   ${cyan}║"
echo -e "${cyan}║${NC}  ${yellow}[2] VMESS               ${cyan}[6] S
ETTINGS${NC}         ${cyan}║"
echo -e "${cyan}║${NC}  ${yellow}[3] VLESS               ${cyan}[7] C
HECK RUNNING${NC}    ${cyan}║"
echo -e "${cyan}║${NC}  ${yellow}[4] TROJAN              ${cyan}[8] C
LEAR RAM${NC}        ${cyan}║"
echo -e "${cyan}╚═══════════════════════════════════════════════╝${NC
}"
echo ""
echo -e "${yellow}[9] REBOOT SERVER"
echo -e "[10] EXIT${NC}"
echo ""
read -p "Select menu : " opt
case $opt in
1) clear ; m-sshovpn ;;
2) clear ; m-vmess ;;
3) clear ; m-vless ;;
4) clear ; m-trojan ;;
5) clear ; m-ssws ;;
6) clear ; m-system ;;
7) clear ; running ;;
8) clear ; clearcache ;;
9) reboot ;;
10) exit ;;
*) echo -e "${red}Invalid Option, Try Again...${NC}" ; sleep 1 ; menu
 ;;
esac
