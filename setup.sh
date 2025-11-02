#!/bin/bash
# =============================
# MAHBOUB INSTALLATION SCRIPT
# =============================
set -euo pipefail

# -----------------------------
# Configure Cloudflare / server defaults
# Replace these defaults if you want, or leave blank to be prompted.
# (If you don't want the token inside the file, remove the value and
# run the script with CF_TOKEN env var set.)
# -----------------------------
CF_TOKEN="${CF_TOKEN:-XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA}"
ZONE_ID="${ZONE_ID:-8761c8222fe8a4d1249e8563eedf43ee}"
DOMAIN="${DOMAIN:-mahboubvps.site}"
SUB_PREFIX="${SUB_PREFIX:-asx}"
SERVER_IP="${SERVER_IP:-$(curl -s https://ipv4.icanhazip.com)}"

LOG="/root/log-install.txt"
LASTLOG="/root/lastlog.txt"

# ----------------------------- logo -----------------------------
print_logo() {
cat <<'EOF'
[0;31m==================================================================
 __  __       _    _     _    _    ____  ____  ____  
|  \/  | __ _| | _| |__ | | _| |  |  _ \/ ___|| __ ) 
| |\/| |/ _` | |/ / '_ \| |/ / |  | | | \___ \|  _ \ 
| |  | | (_| |   <| | | |   <| |__| |_| |___) | |_) |
|_|  |_|\__,_|_|\_\_| |_|_|\_\____|____/|____/|____/ 
==================================================================[0m
EOF
}
# ----------------------------- spinner & bar helpers -----------------------------
run_spinner() {
    local pid=$1
    local msg="$2"
    local spin='|/-\'
    printf "%-44s " "$msg"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b${spin:i%4:1}"
        sleep 0.10
        ((i++))
    done
    wait "$pid"
    local rc=$?
    printf "\b"
    if [ "$rc" -ne 0 ]; then
        printf "\033[31mFAIL\033[0m\n"
        echo "Failed step: $msg" >> "$LOG"
        echo "See $LASTLOG for details." >&2
        tail -n 200 "$LASTLOG"
        exit 1
    else
        printf "\033[32mOK\033[0m\n"
    fi
}

run_with_spinner() {
    local cmd="$1"
    local msg="$2"
    bash -c "$cmd" &> "$LASTLOG" &
    run_spinner $! "$msg"
}

progress_bar_short() {
    local msg="$1"
    printf "%-44s " "$msg"
    for i in $(seq 1 20); do printf "█"; sleep 0.03; done
    printf " \033[32mOK\033[0m\n"
}

# ----------------------------- helper: create CF subdomain -----------------------------
create_cf_subdomain() {
    local prefix=$1
    local domain=$2
    local ip=$3
    local token=$4
    local zone=$5

    # generate random suffix
    local rand
    rand=$(tr -dc a-z0-9 </dev/urandom | head -c5)
    local name="${prefix}-${rand}.${domain}"

    # check existing record
    local out
    out=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records?type=A&name=${name}" \
      -H "Authorization: Bearer ${token}" -H "Content-Type: application/json")

    # if exists and success, return
    if [ "$(echo "$out" | jq -r '.success')" = "true" ] && [ "$(echo "$out" | jq -r '.result | length')" -gt 0 ]; then
        local id
        id=$(echo "$out" | jq -r '.result[0].id')
        echo "$name|$id"
        return 0
    fi

    # create record
    out=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records" \
      -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"${name}\",\"content\":\"${ip}\",\"ttl\":120,\"proxied\":false}")

    if [ "$(echo "$out" | jq -r '.success')" = "true" ]; then
        local id
        id=$(echo "$out" | jq -r '.result.id')
        echo "$name|$id"
        return 0
    else
        # print error for debugging
        echo "CF_ERROR:$out" >&2
        return 1
    fi
}

# ----------------------------- start -----------------------------
clear
print_logo
sleep 0.3

# prepare logs
: > "$LOG"
: > "$LASTLOG"
mkdir -p /etc/xray /etc/v2ray

# ----------------------------- Domain selection -----------------------------
cat <<'MENU'

┌─────────────────────────────┐
│   DOMAIN CONFIGURATION MENU │
└─────────────────────────────┘
  [1] Use Random Domain (Cloudflare)  (uses CF_TOKEN & ZONE_ID)
  [2] Use Your Own Domain
MENU

read -rp "Select option (1/2): " dns_choice
if [ "$dns_choice" = "1" ]; then
    # ensure curl & jq present
    run_with_spinner "apt update -y && apt install -y curl jq" "[SYS] Prepare CF tools"
    # create subdomain calling API (short bar)
    progress_bar_short "[DNS] Creating Cloudflare subdomain"
    if create_cf_subdomain "$SUB_PREFIX" "$DOMAIN" "$SERVER_IP" "$CF_TOKEN" "$ZONE_ID" > /root/.cfresult 2>"$LASTLOG"; then
        cfres=$(cat /root/.cfresult)
        rm -f /root/.cfresult
        subname="${cfres%%|*}"
        echo "$subname" >/root/scdomain
        echo "$subname" >/root/domain
        # also write to /etc/xray, /etc/v2ray and /var/lib/ipvps.conf
        for f in /etc/xray/scdomain /etc/xray/domain /etc/v2ray/domain /var/lib/ipvps.conf; do
            echo "$subname" > "$f"
        done
        printf "[DNS] Subdomain created: \033[32m%s\033[0m -> %s\n" "$subname" "$SERVER_IP"
        dom="$subname"
    else
        echo -e "\033[31m[ERROR]\033[0m Cloudflare API failed; see $LASTLOG"
        tail -n 200 "$LASTLOG"
        exit 1
    fi
else
    read -rp "Enter your domain (example: example.com): " dom
    if [ -z "$dom" ]; then
        echo -e "\033[31m[ERROR]\033[0m Domain cannot be empty"
        exit 1
    fi
    # persist
    for f in /etc/xray/scdomain /etc/xray/domain /etc/v2ray/domain /root/scdomain /root/domain /var/lib/ipvps.conf; do
        echo "$dom" > "$f"
    done
fi

# quick confirm
printf "\nUsing domain: \033[32m%s\033[0m\n\n" "$dom"

# ----------------------------- system update (fast) -----------------------------
progress_bar_short "[SYS] apt update && upgrade"
apt update -y &> "$LASTLOG"
apt upgrade -y &>> "$LASTLOG"

# ----------------------------- dependencies -----------------------------
run_with_spinner "apt install -y git wget python3 dos2unix bc" "[SYS] Installing Dependencies"

# ----------------------------- install services -----------------------------
run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O /root/ssh-vpn.sh && chmod +x /root/ssh-vpn.sh && bash /root/ssh-vpn.sh" "[SSH] Installing SSH WebSocket"

run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O /root/ins-xray.sh && chmod +x /root/ins-xray.sh && bash /root/ins-xray.sh" "[XRAY] Installing Xray"

run_with_spinner "wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O /root/insshws.sh && chmod +x /root/insshws.sh && bash /root/insshws.sh" "[SSHWS] Installing SSHWS"

# ----------------------------- write ports & contact to log -----------------------------
{
  echo "=================================================================="
  echo ""
  echo "   >>> Service & Port"
  echo "   - OpenSSH                  : 22"
  echo "   - SSH Websocket            : 80"
  echo "   - SSH SSL Websocket        : 443"
  echo "   - Stunnel4                 : 222, 777"
  echo "   - Dropbear                 : 109, 143"
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
  echo ""
  echo "=============================Contact=============================="
  echo "---------------------------t.me/givpn-----------------------------"
  echo "=================================================================="
} >> "$LOG"

# ----------------------------- cleanup -----------------------------
run_with_spinner "rm -f /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh /root/cf" "[CLEAN] Cleanup"

# ----------------------------- finish -----------------------------
echo -e "\n\033[0;32m✅ INSTALLATION COMPLETE!\033[0m"
echo "Domain used: $dom"
echo "Persistent log: $LOG"
echo "Last step log (if you need debugging): $LASTLOG"

exit 0
