#!/bin/bash
MYIP=$(wget -qO- ipv4.icanhazip.com)
# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
WHITE='\033[1;97m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'
SELECT="👉"
# Menu options
options=(
"Create SSH & WS Account"
"Trial SSH & WS Account"
"Renew SSH & WS Account"
"Delete SSH & WS Account"
"Check User Login SSH & WS"
"List Member SSH & WS"
"Delete Expired SSH & WS Users"
"Set up Autokill SSH"
"Check Users Multi Login"
"User List of Created Accounts"
"Change SSH Banner"
"Lock User Account"
"Unlock User Account"
"BACK TO MAIN MENU"
"Exit"
)
max=${#options[@]}
selected=0
number_input=""
# Determine box width
max_length=0
for opt in "${options[@]}"; do
  [[ ${#opt} -gt $max_length ]] && max_length=${#opt}
done
box_length=$((max_length + 20))
draw_menu() {
  clear
  echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $box_length))╗${NC}"
  echo -e "${CYAN}║${WHITE}${BOLD}           SSH & WS MANAGEMENT${CYAN}                   ║${NC}"
  echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $box_length))╣${NC}"
  printf "${CYAN}║ ${WHITE}VPS IP:${GRAY} %-$(($box_length-11))s ${CYAN} ║${NC}\n" "$MYIP"
  echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $box_length))╣${NC}"
  for i in "${!options[@]}"; do
    num=$((i+1))
    text="$num) ${options[$i]}"
    [[ $i -eq $selected ]] && prefix="${SELECT}${WHITE}${BOLD}" || prefix="  ${GRAY}"
    printf "${CYAN}║ ${prefix}%-$(($box_length-4))s${NC} ${CYAN}║${NC}\n" "$text"
  done
  echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $box_length))╝${NC}"
  echo -e "${RED}Use ↑/↓ arrows, Touch, or Type Number (1-$max), Enter to select${NC}"
}
tput civis
while true; do
  draw_menu
  read -rsn1 key
  if [[ $key == $'\x1b' ]]; then
    read -rsn2 -t 0.05 key
  fi
  case "$key" in
    '[A') ((selected--)); [[ $selected -lt 0 ]] && selected=$((max-1)) ;;
    '[B') ((selected++)); [[ $selected -ge max ]] && selected=0 ;;
    '') break ;; # ENTER
    [0-9])
       number_input+="$key"
       if (( number_input >= 1 && number_input <= max )); then
         selected=$((number_input-1))
       fi
       [[ ${#number_input} -ge 2 ]] && number_input="" ;;
    *) number_input="" ;;
  esac
done
tput cnorm
case $selected in
  0) clear ; usernew ;;
  1) clear ; trial ;;
  2) clear ; renew ;;
  3) clear ; hapus ;;
  4) clear ; cek ;;
  5) clear ; member ;;
  6) clear ; delete ;;
  7) clear ; autokill ;;
  8) clear ; ceklim ;;
  9) clear ; cat /etc/log-create-ssh.log ;;
  10) clear ; nano /etc/issue.net ;;
  11) clear ; user-lock ;;
  12) clear ; user-unlock ;;
  13) clear ; menu ;;
  14) clear ; exit ;;
esac
