#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - LIBRARY FUNCTIONS
#   Supports: VMess, VLess, Trojan, Shadowsocks (WS/gRPC)
#             SSH-WS/SSL, SlowDNS, wstunnel
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
DB_DIR="$SCRIPT_DIR/db"
XRAY_CONFIG="/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"

# ─── Port Configuration ─────────────────────────────────────
WS_OPENSSH_PORT=2093
WS_DROPBEAR_PORT=2095
WS_STUNNEL_LOCAL_PORT=700
STUNNEL_SSL_PORT=445
WSTUNNEL_PORT=8880
NGINX_TLS_INTERNAL_PORT=8443
XRAY_API_PORT=62731

# ─── Database Files ─────────────────────────────────────────
DB_VMESS="$DB_DIR/vmess.db"
DB_VLESS="$DB_DIR/vless.db"
DB_TROJAN="$DB_DIR/trojan.db"
DB_SS="$DB_DIR/ss.db"
DB_SSH="$DB_DIR/ssh.db"

# ─── Colors ─────────────────────────────────────────────────
R='\033[0;31m';    G='\033[0;32m';    Y='\033[0;33m'
B='\033[0;34m';    M='\033[0;35m';    C='\033[0;36m'
W='\033[0;37m';    D='\033[0;2m'
RB='\033[1;31m';   GB='\033[1;32m';   YB='\033[1;33m'
BB='\033[1;34m';   MB='\033[1;35m';   CB='\033[1;36m'
WB='\033[1;37m'
BG='\033[42m';     BR='\033[41m'
NC='\033[0m'

# ─── Box Drawing Helpers ────────────────────────────────────
box_top() {
    local title="$1" width="${2:-62}"
    local pad=$(( (width - ${#title} - 4) / 2 ))
    local left=$((pad > 0 ? pad : 0))
    local right=$((width - ${#title} - 4 - left))
    local sep=$(printf '%*s' "$width" '' | tr ' ' '═')
    local lpad=$(printf '%*s' "$left" '' | tr ' ' ' ')
    local rpad=$(printf '%*s' "$right" '' | tr ' ' ' ')
    echo -e "${C}╔${sep}╗${NC}"
    echo -e "${C}║${NC}  ${WB}${title}${NC}  ${lpad}${rpad} ${C}║${NC}"
    echo -e "${C}╠${sep}╣${NC}"
}

box_mid() {
    local width="${1:-62}"
    local sep=$(printf '%*s' "$width" '' | tr ' ' '═')
    echo -e "${C}╠${sep}╣${NC}"
}

box_row() {
    local label="$1" value="$2" width="${3:-62}"
    local content="${W}  ${label}${NC} ${D}:${NC} ${value}"
    local pad=$((width - ${#label} - ${#value} - 6))
    if [[ $pad -lt 1 ]]; then pad=1; fi
    local sp=$(printf '%*s' "$pad" '' | tr ' ' ' ')
    echo -e "${C}║${NC}${content}${sp} ${C}║${NC}"
}

box_row_color() {
    local label="$1" value="$2" color="$3" width="${4:-62}"
    local content="${W}  ${label}${NC} ${D}:${NC} ${!color}${value}${NC}"
    echo -e "${C}║${NC}${content} $(printf '%*s' $((width - ${#label} - ${#value} - 6)) '' | tr ' ' ' ') ${C}║${NC}"
}

box_empty() {
    local width="${1:-62}"
    echo -e "${C}║${NC}$(printf '%*s' "$width" '' | tr ' ' ' ') ${C}║${NC}"
}

box_bot() {
    local width="${1:-62}"
    local sep=$(printf '%*s' "$width" '' | tr ' ' '═')
    echo -e "${C}╚${sep}╝${NC}"
}

box_menu_item() {
    local num="$1" text="$2" width="${3:-62}"
    local content="    ${GB}[${num}]${NC}  ${W}${text}${NC}"
    echo -e "${C}║${NC}${content} $(printf '%*s' $((width - ${#num} - ${#text} - 8)) '' | tr ' ' ' ') ${C}║${NC}"
}

box_menu_item_dim() {
    local num="$1" text="$2" width="${3:-62}"
    local content="    ${D}[${num}]${NC}  ${D}${text}${NC}"
    echo -e "${C}║${NC}${content} $(printf '%*s' $((width - ${#num} - ${#text} - 8)) '' | tr ' ' ' ') ${C}║${NC}"
}

status_dot() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "${GB}● RUNNING${NC}"
    else
        echo -e "${RB}● STOPPED${NC}"
    fi
}

status_text() {
    systemctl is-active --quiet "$1" 2>/dev/null && echo "RUNNING" || echo "STOPPED"
}

# ─── Domain / IP Helpers ────────────────────────────────────
get_domain() {
    cat "$SCRIPT_DIR/domain" 2>/dev/null || echo "unknown"
}

get_server_ip() {
    curl -s4 --max-time 3 https://ifconfig.me 2>/dev/null || \
    curl -s4 --max-time 3 https://api.ipify.org 2>/dev/null || \
    hostname -I | awk '{print $1}'
}

# ─── System Info ────────────────────────────────────────────
get_cpu_info() {
    grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//'
}

get_cpu_cores() { nproc; }

get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "N/A"
}

get_mem_usage() {
    free -m | awk 'NR==2{printf "%sMB / %sMB (%.0f%%)", $3, $2, $3*100/$2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}'
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/up //' || uptime | awk '{print $3,$4}' | sed 's/,//'
}

get_os_info() {
    . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || cat /etc/issue | head -1
}

get_kernel() { uname -r; }

get_load_avg() { uptime | awk -F'load average: ' '{print $2}'; }

get_xray_version() {
    $XRAY_BIN version 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A"
}

get_network_usage() {
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$iface" ]]; then
        local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        echo "$(numfmt --to=iec $rx 2>/dev/null || echo ${rx}B) / $(numfmt --to=iec $tx 2>/dev/null || echo ${tx}B)"
    else
        echo "N/A"
    fi
}

# ─── UUID / Password Generators ─────────────────────────────
gen_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || \
    openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}

gen_password() {
    openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 16
}

gen_ssh_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 10 || \
    openssl rand -base64 8 | tr -dc 'A-Za-z0-9' | head -c 10
}

# ─── Date Helpers ───────────────────────────────────────────
get_exp_date() {
    local days="$1"
    date -d "+${days} days" +"%Y-%m-%d"
}

days_until_exp() {
    local exp="$1"
    local today=$(date +%s)
    local expd=$(date -d "$exp" +%s 2>/dev/null || echo 0)
    echo $(( (expd - today) / 86400 ))
}

is_expired() {
    local exp="$1"
    [[ $(days_until_exp "$exp") -lt 0 ]]
}

# ════════════════════════════════════════════════════════════
#  VMESS ACCOUNT MANAGEMENT
# ════════════════════════════════════════════════════════════
create_vmess() {
    local username="$1" days="$2"
    local uuid=$(gen_uuid)
    local exp=$(get_exp_date "$days")
    local created=$(date +"%Y-%m-%d")
    echo "$username|$uuid|$exp|$created" >> "$DB_VMESS"

    local tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg email "$username" \
        '(.inbounds[] | select(.tag == "vmess-ws-tls" or .tag == "vmess-ws-ntls") | .settings.clients) += [{"id": $uuid, "alterId": 0, "email": $email}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
    echo "$uuid"
}

delete_vmess() {
    local username="$1"
    sed -i "/^${username}|/d" "$DB_VMESS"
    local tmp=$(mktemp)
    jq --arg email "$username" \
        '(.inbounds[] | select(.tag | startswith("vmess")) | .settings.clients) |= map(select(.email != $email))' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

renew_vmess() {
    local username="$1" days="$2"
    local exp=$(get_exp_date "$days")
    sed -i "s/^${username}|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)\$/${username}|\\1|${exp}|\\3/" "$DB_VMESS"
}

get_vmess_info() { grep "^${1}|" "$DB_VMESS" 2>/dev/null; }
list_vmess() { cat "$DB_VMESS" 2>/dev/null; }
count_vmess() { wc -l < "$DB_VMESS" 2>/dev/null || echo 0; }

# ════════════════════════════════════════════════════════════
#  VLESS ACCOUNT MANAGEMENT
# ════════════════════════════════════════════════════════════
create_vless() {
    local username="$1" days="$2"
    local uuid=$(gen_uuid)
    local exp=$(get_exp_date "$days")
    local created=$(date +"%Y-%m-%d")
    echo "$username|$uuid|$exp|$created" >> "$DB_VLESS"

    local tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg email "$username" \
        '(.inbounds[] | select(.tag == "vless-ws-tls" or .tag == "vless-ws-ntls" or .tag == "vless-grpc-tls") | .settings.clients) += [{"id": $uuid, "email": $email, "flow": ""}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
    echo "$uuid"
}

delete_vless() {
    local username="$1"
    sed -i "/^${username}|/d" "$DB_VLESS"
    local tmp=$(mktemp)
    jq --arg email "$username" \
        '(.inbounds[] | select(.tag | startswith("vless")) | .settings.clients) |= map(select(.email != $email))' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

renew_vless() {
    local username="$1" days="$2"
    local exp=$(get_exp_date "$days")
    sed -i "s/^${username}|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)\$/${username}|\\1|${exp}|\\3/" "$DB_VLESS"
}

get_vless_info() { grep "^${1}|" "$DB_VLESS" 2>/dev/null; }
list_vless() { cat "$DB_VLESS" 2>/dev/null; }
count_vless() { wc -l < "$DB_VLESS" 2>/dev/null || echo 0; }

# ════════════════════════════════════════════════════════════
#  TROJAN ACCOUNT MANAGEMENT
# ════════════════════════════════════════════════════════════
create_trojan() {
    local username="$1" days="$2"
    local password=$(gen_password)
    local exp=$(get_exp_date "$days")
    local created=$(date +"%Y-%m-%d")
    echo "$username|$password|$exp|$created" >> "$DB_TROJAN"

    local tmp=$(mktemp)
    jq --arg pass "$password" --arg email "$username" \
        '(.inbounds[] | select(.tag | startswith("trojan")) | .settings.clients) += [{"password": $pass, "email": $email}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
    echo "$password"
}

delete_trojan() {
    local username="$1"
    local password=$(grep "^${username}|" "$DB_TROJAN" | cut -d'|' -f2)
    sed -i "/^${username}|/d" "$DB_TROJAN"
    local tmp=$(mktemp)
    jq --arg pass "$password" \
        '(.inbounds[] | select(.tag | startswith("trojan")) | .settings.clients) |= map(select(.password != $pass))' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

renew_trojan() {
    local username="$1" days="$2"
    local exp=$(get_exp_date "$days")
    sed -i "s/^${username}|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)\$/${username}|\\1|${exp}|\\3/" "$DB_TROJAN"
}

get_trojan_info() { grep "^${1}|" "$DB_TROJAN" 2>/dev/null; }
list_trojan() { cat "$DB_TROJAN" 2>/dev/null; }
count_trojan() { wc -l < "$DB_TROJAN" 2>/dev/null || echo 0; }

# ════════════════════════════════════════════════════════════
#  SHADOWSOCKS ACCOUNT MANAGEMENT
# ════════════════════════════════════════════════════════════
create_ss() {
    local username="$1" days="$2"
    local password=$(gen_password)
    local method="aes-128-gcm"
    local exp=$(get_exp_date "$days")
    local created=$(date +"%Y-%m-%d")
    echo "$username|$password|$method|$exp|$created" >> "$DB_SS"

    local tmp=$(mktemp)
    jq --arg pass "$password" --arg method "$method" \
        '(.inbounds[] | select(.tag | startswith("ss-")) | .settings.clients) += [{"method": $method, "password": $pass}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
    echo "$password"
}

delete_ss() {
    local username="$1"
    local password=$(grep "^${username}|" "$DB_SS" | cut -d'|' -f2)
    sed -i "/^${username}|/d" "$DB_SS"
    local tmp=$(mktemp)
    jq --arg pass "$password" \
        '(.inbounds[] | select(.tag | startswith("ss-")) | .settings.clients) |= map(select(.password != $pass))' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

renew_ss() {
    local username="$1" days="$2"
    local exp=$(get_exp_date "$days")
    sed -i "s/^${username}|\\([^|]*\\)|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)\$/${username}|\\1|\\2|${exp}|\\4/" "$DB_SS"
}

get_ss_info() { grep "^${1}|" "$DB_SS" 2>/dev/null; }
list_ss() { cat "$DB_SS" 2>/dev/null; }
count_ss() { wc -l < "$DB_SS" 2>/dev/null || echo 0; }

# ════════════════════════════════════════════════════════════
#  SSH ACCOUNT MANAGEMENT
# ════════════════════════════════════════════════════════════
create_ssh() {
    local username="$1" days="$2" password="${3:-$(gen_ssh_password)}"
    local exp=$(get_exp_date "$days")
    local created=$(date +"%Y-%m-%d")
    useradd -e "$exp" -s /bin/false -M "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    echo "$username|$password|$exp|$created" >> "$DB_SSH"
    echo "$password"
}

delete_ssh() {
    local username="$1"
    userdel -f "$username" 2>/dev/null
    sed -i "/^${username}|/d" "$DB_SSH"
}

renew_ssh() {
    local username="$1" days="$2"
    local exp=$(get_exp_date "$days")
    chage -E "$exp" "$username" 2>/dev/null
    sed -i "s/^${username}|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)\$/${username}|\\1|${exp}|\\3/" "$DB_SSH"
}

get_ssh_info() { grep "^${1}|" "$DB_SSH" 2>/dev/null; }
list_ssh() { cat "$DB_SSH" 2>/dev/null; }
count_ssh() { wc -l < "$DB_SSH" 2>/dev/null || echo 0; }

delete_expired_ssh() {
    local today=$(date +%s)
    while IFS='|' read -r user pass exp created; do
        [[ -z "$user" ]] && continue
        local expd=$(date -d "$exp" +%s 2>/dev/null || echo 0)
        if [[ $expd -lt $today ]]; then
            delete_ssh "$user"
            echo "[$(date)] Deleted expired SSH: $user (exp: $exp)"
        fi
    done < <(list_ssh)
}

# ════════════════════════════════════════════════════════════
#  DELETE ALL EXPIRED ACCOUNTS
# ════════════════════════════════════════════════════════════
delete_expired() {
    local today=$(date +%s)
    local db_file label key_field del_fn
    for db_file label key_field in \
        "$DB_VMESS" "VMess" "uuid" "delete_vmess" \
        "$DB_VLESS" "VLess" "uuid" "delete_vless" \
        "$DB_TROJAN" "Trojan" "password" "delete_trojan" \
        "$DB_SS" "SS" "password" "delete_ss"; do
        while IFS='|' read -r user _ exp _; do
            [[ -z "$user" ]] && continue
            local expd=$(date -d "$exp" +%s 2>/dev/null || echo 0)
            if [[ $expd -lt $today ]]; then
                $del_fn "$user"
                echo "[$(date)] Deleted expired $label: $user (exp: $exp)"
            fi
        done < <(cat "$db_file" 2>/dev/null)
    done
    delete_expired_ssh
}

# ════════════════════════════════════════════════════════════
#  LINK GENERATORS
# ════════════════════════════════════════════════════════════
gen_vmess_link() {
    local user="$1" uuid="$2" domain="$3" type="${4:-tls}" remark="$5"
    local port path
    if [[ "$type" == "tls" ]]; then port=443; path="/vmess-ws"; else port=80; path="/vmess-ntls"; fi
    local json="{\"v\":\"2\",\"ps\":\"${remark:-$user-vmess-$type}\",\"add\":\"$domain\",\"port\":\"$port\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$domain\",\"path\":\"$path\",\"tls\":\"$([ "$type" == "tls" ] && echo "tls" || echo "")\",\"sni\":\"$domain\"}"
    echo "vmess://$(echo -n "$json" | base64 -w 0)"
}

gen_vless_link() {
    local user="$1" uuid="$2" domain="$3" type="${4:-tls}" remark="$5"
    local port path security
    if [[ "$type" == "tls" ]]; then port=443; path="/vless-ws"; security="tls"
    elif [[ "$type" == "grpc" ]]; then port=443; path="vless-grpc"; security="tls"
    else port=80; path="/vless-ntls"; security="none"; fi
    if [[ "$type" == "grpc" ]]; then
        echo "vless://${uuid}@${domain}:${port}?encryption=none&security=${security}&type=grpc&serviceName=${path}&sni=${domain}#${remark:-$user-vless-grpc}"
    else
        echo "vless://${uuid}@${domain}:${port}?encryption=none&security=${security}&type=ws&host=${domain}&path=${path}&sni=${domain}#${remark:-$user-vless-$type}"
    fi
}

gen_trojan_link() {
    local user="$1" pass="$2" domain="$3" type="${4:-ws}" remark="$5"
    local path
    if [[ "$type" == "grpc" ]]; then
        path="trojan-grpc"
        echo "trojan://${pass}@${domain}:443?security=tls&type=grpc&serviceName=${path}&sni=${domain}#${remark:-$user-trojan-grpc}"
    else
        path="/trojan-ws"
        echo "trojan://${pass}@${domain}:443?security=tls&type=ws&host=${domain}&path=${path}&sni=${domain}#${remark:-$user-trojan-ws}"
    fi
}

gen_ss_link() {
    local user="$1" pass="$2" domain="$3" type="${4:-ws}" remark="$5"
    local method="aes-128-gcm" path
    if [[ "$type" == "grpc" ]]; then
        path="ss-grpc"
        local base="${method}:${pass}"
        echo "ss://$(echo -n "$base" | base64 -w 0)@${domain}:443?security=tls&type=grpc&serviceName=${path}&sni=${domain}#${remark:-$user-ss-grpc}"
    else
        path="/ss-ws"
        local base="${method}:${pass}"
        echo "ss://$(echo -n "$base" | base64 -w 0)@${domain}:443?security=tls&type=ws&host=${domain}&path=${path}&sni=${domain}#${remark:-$user-ss-ws}"
    fi
}

# ════════════════════════════════════════════════════════════
#  SERVICE MANAGEMENT
# ════════════════════════════════════════════════════════════
MANAGED_SERVICES=(xray nginx dropbear stunnel4 ws-openssh ws-dropbear ws-stunnel proxy--ws haproxy)

is_service_installed() {
    systemctl list-unit-files 2>/dev/null | grep -q "^${1}\.service" && return 0
    command -v "$1" &>/dev/null && return 0
    return 1
}

# ════════════════════════════════════════════════════════════
#  CHANGE DOMAIN
# ════════════════════════════════════════════════════════════
change_domain() {
    local new_domain="$1"
    local old_domain=$(get_domain)

    sed -i "s/$old_domain/$new_domain/g" /etc/nginx/conf.d/xray.conf 2>/dev/null
    systemctl stop nginx 2>/dev/null

    /root/.acme.sh/acme.sh --issue --standalone -d "$new_domain" \
        --keylength ec-256 --httpport 80 2>/dev/null

    /root/.acme.sh/acme.sh --installcert -d "$new_domain" \
        --ecc \
        --key-file /etc/ssl/xray/xray.key \
        --fullchain-file /etc/ssl/xray/xray.crt \
        --reloadcmd "systemctl restart xray nginx 2>/dev/null" 2>/dev/null

    echo "$new_domain" > "$SCRIPT_DIR/domain"

    # Update stunnel cert
    if [[ -f /etc/ssl/xray/xray.crt && -f /etc/ssl/xray/xray.key ]]; then
        cat /etc/ssl/xray/xray.crt /etc/ssl/xray/xray.key > /etc/stunnel/stunnel.pem 2>/dev/null
        chmod 600 /etc/stunnel/stunnel.pem
    fi

    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null
    systemctl restart xray 2>/dev/null
    systemctl restart stunnel4 2>/dev/null
}

# ════════════════════════════════════════════════════════════
#  AUTO-UPDATE
# ════════════════════════════════════════════════════════════
UPDATE_RAW="https://raw.githubusercontent.com/chanelog/xray/main"
VERSION_FILE="$SCRIPT_DIR/VERSION"

get_local_version() { cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0"; }
get_remote_version() { curl -s --max-time 10 "$UPDATE_RAW/VERSION" 2>/dev/null; }

check_update_available() {
    local local_v remote_v
    local_v=$(get_local_version)
    remote_v=$(get_remote_version)
    [[ -z "$remote_v" ]] && return 1
    [[ "$local_v" != "$remote_v" ]] && { echo "$remote_v"; return 0; }
    return 1
}

# ════════════════════════════════════════════════════════════
#  WS PAYLOAD HELPER
# ════════════════════════════════════════════════════════════
ws_payload_string() {
    local domain="$1" port="${2:-80}"
    printf 'GET /ssh-ws HTTP/1.1[crlf]Host: %s[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]' "$domain"
}

# ════════════════════════════════════════════════════════════
#  PROMPT HELPERS
# ════════════════════════════════════════════════════════════
press_enter() {
    echo -ne "\n  ${D}Tekan Enter untuk kembali...${NC}"; read -r
}

confirm() {
    local msg="$1" default="${2:-n}"
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="${W}  ${msg} [Y/n]${NC}: "
    else
        prompt="${W}  ${msg} [y/N]${NC}: "
    fi
    echo -ne "$prompt"
    local c; read -r c
    if [[ "$default" == "y" ]]; then
        [[ ! "$c" =~ ^[Nn]$ ]]
    else
        [[ "$c" =~ ^[Yy]$ ]]
    fi
}

# Make functions available when sourced
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && "$@"