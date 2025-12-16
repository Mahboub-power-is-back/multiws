#!/bin/bash
# ============================================
# VPS CONTROL PANEL v4.0 - MINIMAL DESIGN
# ============================================
# COLOR SCHEME
RED='\e[1;31m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
WHITE='\e[1;97m'
MAGENTA='\e[1;35m'
RESET='\e[0m'
# FETCH SYSTEM DATA
get_sys_info() {
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "Not Set")
    NSDOMAIN=$(cat nsdomain)
    UPTIME=$(uptime -p | sed 's/up //')
    IPVPS=$(curl -s ifconfig.me)
    LOC=$(curl -s ifconfig.co/country)
    RAM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
    RAM_USED=$(free -m | awk 'NR==2 {print $3}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}' | sed 's/G//')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
    LOAD=$(cat /proc/loadavg | awk '{print $1}')
    CORES=$(nproc)
}
# CLEAR SCREEN AND SHOW HEADER
clear_screen() {
    clear
    echo -e "${BLUE}=====================================================${RESET}"
    echo -e "${BLUE}   ||${RESET} ${CYAN}▀▄▀▄▀▄ VPS CONTROL PANEL v4.0 ▄▀▄▀▄▀${RESET} ${BLUE}||${RESET}"
    echo -e "${BLUE}=====================================================${RESET}"
    echo ""
}
# DISPLAY SYSTEM INFO
show_system_info() {
    echo -e "${CYAN}         ◼ SYSTEM INFORMATION${RESET}"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
    # Line 1
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}Uptime${RESET}    : ${YELLOW}$UPTIME${RESET}"
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}IP${RESET}
     : ${YELLOW}$IPVPS${RESET}"
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}Location${RESET}  : ${YELLOW}$LOC${RESET}"
    # Line 2
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}Domain${RESET}    : ${YELLOW}$DOMAIN${RESET}"
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}Load${RESET}
     : ${YELLOW}$LOAD${RESET} (${WHITE}$CORES${RESET} cores)"
    # Line 3 - Resources
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}RAM${RESET}
     : ${YELLOW}$RAM_USED${RESET}MB / ${YELLOW}$RAM_TOTAL${RESET}MB"
    echo -e "${BLUE}│${RESET} ${GREEN}•${RESET} ${WHITE}Disk${RESET}
     : ${YELLOW}$DISK_USED${RESET}GB / ${YELLOW}$DISK_TOTAL${RESET}GB"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${RESET}"
    echo ""
}
# DISPLAY MENU OPTIONS
show_menu_options() {
    echo -e "${CYAN}         ◼ SERVICE MANAGEMENT${RESET}"
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${RESET}"
    # Column headers
    echo -e "${BLUE}│${RESET} ${WHITE}Protocol Services${RESET}
     ${BLUE}│${RESET} ${WHITE}System Tools${RESET}      ${BLUE}│${RESET}"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
    # Row 1
    echo -e "${BLUE}│${RESET} ${GREEN}[1]${RESET} ${WHITE}SSH
  ${RESET}           ${BLUE}│${RESET} ${GREEN}[5]${RESET} ${WHITE}Shadowsocks${RESET}   ${BLUE}│${RESET}"
    # Row 2
    echo -e "${BLUE}│${RESET} ${GREEN}[2]${RESET} ${WHITE}VMESS${RESET}                   ${BLUE}│${RESET} ${GREEN}[6]${RESET} ${WHITE}Settings${RESET}      ${BLUE}│${RESET}"
    # Row 3
    echo -e "${BLUE}│${RESET} ${GREEN}[3]${RESET} ${WHITE}VLESS${RESET}                   ${BLUE}│${RESET} ${GREEN}[7]${RESET} ${WHITE}Check Running${RESET} ${BLUE}│${RESET}"
    # Row 4
    echo -e "${BLUE}│${RESET} ${GREEN}[4]${RESET} ${WHITE}Trojan${RESET}                  ${BLUE}│${RESET} ${GREEN}[8]${RESET} ${WHITE}Clear RAM${RESET}     ${BLUE}│${RESET}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${RESET}"
    echo ""
}
# DISPLAY ACTIONS
show_actions() {
    echo -e "${CYAN}         ◼ SYSTEM ACTIONS${RESET}"
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${RESET}"
    echo -e "${BLUE}│${RESET} ${GREEN}[9]${RESET}  ${RED}Reboot Server${RESET}             ${GREEN}[10]${RESET} ${RED}Exit${RESET}
${BLUE}│${RESET}"
    echo -e "${BLUE}└─────────────────────────────────────────────────┘${RESET}"
    echo ""
}
# USER INPUT
get_user_input() {
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}║${RESET} ${WHITE}Enter selection ${CYAN}[1-10]${WHITE}:${RESET}                       ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}║${RESET} ${GREEN}▸${RESET} ${YELLOW}
                                   ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${RESET}"
read -p "" OPTION""
}
# PROCESS SELECTION
process_selection() {
    case $OPTION in
        1)
            echo -e "${GREEN}▶ Loading SSH & OpenVPN...${RESET}"
            sleep 1
            clear
            m-sshovpn
            ;;
        2)
            echo -e "${GREEN}▶ Loading VMESS...${RESET}"
            sleep 1
            clear
            m-vmess
            ;;
        3)
            echo -e "${GREEN}▶ Loading VLESS...${RESET}"
            sleep 1
            clear
            m-vless
            ;;
        4)
            echo -e "${GREEN}▶ Loading Trojan...${RESET}"
            sleep 1
            clear
            m-trojan
            ;;
        5)
            echo -e "${GREEN}▶ Loading Shadowsocks...${RESET}"
            sleep 1
            clear
            m-ssws
            ;;
        6)
            echo -e "${GREEN}▶ Loading Settings...${RESET}"
            sleep 1
            clear
            m-system
            ;;
        7)
            echo -e "${GREEN}▶ Checking Services...${RESET}"
            sleep 1
            clear
            running
            ;;
        8)
            echo -e "${GREEN}▶ Clearing RAM...${RESET}"
            sleep 1
            clear
            clearcache
            ;;
        9)
            echo -e "${RED}⚠ Warning: System will reboot!${RESET}"
            echo -e "${YELLOW}Press Ctrl+C to cancel within 3 seconds...${RESET}"
            sleep 3
            echo -e "${GREEN}▶ Rebooting...${RESET}"
            reboot
            ;;
        10)
            echo -e "${CYAN}▶ Exiting...${RESET}"
            sleep 1
            clear
            exit 0
            ;;
        *)
            echo -e "${RED}✗ Invalid option! Please select 1-10${RESET}"
            sleep 2
            exec /usr/bin/menu
            ;;
    esac
}
# MAIN FUNCTION
main() {
    get_sys_info
    clear_screen
    show_system_info
    show_menu_options
    show_actions
    get_user_input
    process_selection
}
# START
main
