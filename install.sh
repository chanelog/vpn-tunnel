#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - MAIN INSTALLER
#   All-in-One VPN Tunnel Manager
#   Supports: VMess, VLess, Trojan, SS (WS/gRPC + TLS/non-TLS)
#             SSH-WS (OpenSSH/Dropbear), SSH-SSL (Stunnel4)
#   Repository: https://github.com/YOURUSER/vpn-tunnel
# ============================================================

set -e

SCRIPT_DIR="/etc/proxmaster"
BIN_DIR="/usr/local/bin"
XRAY_DIR="/etc/xray"
SSL_DIR="/etc/ssl/xray"

# ─── Colors (standalone, no lib.sh yet) ─────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; W='\033[0;37m'; NC='\033[0m'
RB='\033[1;31m'; GB='\033[1;32m'; YB='\033[1;33m'; CB='\033[1;36m'; WB='\033[1;37m'

log_ok()   { echo -e "  ${G}[OK]${NC} $1"; }
log_fail() { echo -e "  ${R}[FAIL]${NC} $1"; }
log_info() { echo -e "  ${C}[*]${NC} $1"; }
log_warn() { echo -e "  ${Y}[!]${NC} $1"; }
log_step() { echo -e "\n  ${CB}[STEP $1]${NC} $2"; }

progress() {
    local msg="$1" total="$2" current="$3"
    local pct=$(( current * 100 / total ))
    local filled=$(( pct / 2 ))
    local empty=$(( 50 - filled ))
    local bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
    local spc=$(printf '%*s' "$empty" '' | tr ' ' '░')
    printf "\r  ${C}[*]${NC} ${msg} [${GB}${bar}${spc}${NC}] ${pct}%%   "
}

# ─── Check Root ─────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RB}[ERROR]${NC} Script harus dijalankan sebagai root!"
    exit 1
fi

# ─── Check OS ───────────────────────────────────────────────
. /etc/os-release 2>/dev/null
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo -e "${RB}[ERROR]${NC} Script hanya mendukung Ubuntu/Debian!"
    exit 1
fi

# ─── Banner ─────────────────────────────────────────────────
clear
echo -e "${CB}"
cat <<'BANNER'
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │     ██████╗██╗   ██╗██████╗ ███████╗██████╗              │
  │    ██╔═══╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗             │
  │    ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝             │
  │    ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗             │
  │    ╚██████╗   ██║   ██████╔╝███████╗██║  ██║             │
  │     ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝             │
  │                                                          │
  │            V P N  T U N N E L  S U I T E                 │
  │                                                          │
  │    VMess | VLess | Trojan | Shadowsocks | SSH-WS/SSL     │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
BANNER
echo -e "${NC}"
echo -e "${W}             Advanced VPN Tunnel Manager v1.0.0${NC}"
echo -e "${Y}         ═══════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════
#  STEP 1: INPUT DOMAIN
# ════════════════════════════════════════════════════════════
TOTAL_STEPS=10
STEP=1

log_step "$STEP/$TOTAL_STEPS" "KONFIGURASI DOMAIN"
echo ""

while true; do
    echo -ne "  ${WB}Masukkan domain${NC} (sudah diarahkan ke IP VPS ini): "
    read -r DOMAIN
    DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z "$DOMAIN" ]]; then
        log_fail "Domain tidak boleh kosong!"
        continue
    fi

    if ! echo "$DOMAIN" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
        log_fail "Format domain tidak valid!"
        continue
    fi

    echo ""
    log_info "Memverifikasi domain ${WB}$DOMAIN${NC} ..."

    SERVER_IP=$(curl -s4 --max-time 10 https://ifconfig.me 2>/dev/null || \
                curl -s4 --max-time 10 https://api.ipify.org 2>/dev/null || \
                curl -s4 --max-time 10 https://ipv4.icanhazip.com 2>/dev/null)
    DOMAIN_IP=$(dig +short "$DOMAIN" A 2>/dev/null | grep -E '^[0-9]+\.' | tail -1)

    if [[ -z "$SERVER_IP" ]]; then
        log_warn "Tidak bisa cek IP server, lanjut tanpa verifikasi..."
        break
    fi

    if [[ -z "$DOMAIN_IP" ]]; then
        log_warn "DNS domain belum ditemukan."
        echo -ne "  Lanjutkan meski DNS belum propagasi? [y/N]: "
        read -r FORCE
        [[ "$FORCE" =~ ^[Yy]$ ]] && break
        continue
    fi

    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        log_ok "Domain ${WB}$DOMAIN${NC} -> ${GB}$SERVER_IP${NC} VERIFIED"
        break
    else
        log_warn "Domain -> $DOMAIN_IP, Server -> $SERVER_IP (tidak cocok)"
        echo -ne "  Lanjutkan? [y/N]: "
        read -r FORCE
        [[ "$FORCE" =~ ^[Yy]$ ]] && break
    fi
done
echo "$DOMAIN" > /tmp/proxmaster_domain.tmp

# ════════════════════════════════════════════════════════════
#  STEP 2: INSTALL DEPENDENCIES
# ════════════════════════════════════════════════════════════
STEP=2
log_step "$STEP/$TOTAL_STEPS" "INSTALL DEPENDENSI DASAR"
echo ""

DEPS=(curl wget gnupg2 ca-certificates lsb-release uuid-runtime jq \
      nginx python3 python3-venv openssl net-tools iptables \
      stunnel4 dropbear socat dnsutils cron)

apt-get update -qq
for pkg in "${DEPS[@]}"; do
    echo -ne "  ${C}[*]${NC} Install $pkg ... "
    if apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
        echo -e "${G}OK${NC}"
    else
        echo -e "${Y}SKIP${NC} (mungkin sudah ada)"
    fi
done
log_ok "Dependensi dasar terinstall"

# ════════════════════════════════════════════════════════════
#  STEP 3: INSTALL XRAY CORE
# ════════════════════════════════════════════════════════════
STEP=3
log_step "$STEP/$TOTAL_STEPS" "INSTALL XRAY CORE"
echo ""

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  XRAY_ARCH="amd64" ;;
    aarch64) XRAY_ARCH="arm64-v8a" ;;
    *)       log_fail "Arsitektur $ARCH tidak didukung!"; exit 1 ;;
esac

XRAY_VER="v1.8.24"
XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip"

log_info "Mendownload Xray ($XRAY_ARCH) ..."
if wget -q --show-progress --timeout=60 "$XRAY_URL" -O /tmp/xray.zip 2>&1; then
    log_ok "Xray didownload"
    log_info "Mengekstrak Xray ..."
    unzip -oq /tmp/xray.zip -d /tmp/xray_extract
    install -m 755 /tmp/xray_extract/xray "$BIN_DIR/xray"
    rm -rf /tmp/xray.zip /tmp/xray_extract
    log_ok "Xray terinstall di $BIN_DIR/xray"
    xray version | head -1
else
    log_fail "Gagal download Xray! Cek koneksi internet."
    exit 1
fi

# ════════════════════════════════════════════════════════════
#  STEP 4: SSL CERTIFICATE (ACME.SH)
# ════════════════════════════════════════════════════════════
STEP=4
log_step "$STEP/$TOTAL_STEPS" "SSL CERTIFICATE (ACME.SH)"
echo ""

mkdir -p "$SSL_DIR"

# Stop services that use port 80/443
systemctl stop nginx 2>/dev/null || true
systemctl stop xray 2>/dev/null || true
systemctl stop haproxy 2>/dev/null || true

# Install acme.sh if not present
if [[ ! -f /root/.acme.sh/acme.sh ]]; then
    log_info "Menginstall acme.sh ..."
    curl -fsSL https://get.acme.sh | sh -s email=admin@$DOMAIN 2>/dev/null
    log_ok "acme.sh terinstall"
else
    log_ok "acme.sh sudah terinstall"
fi

log_info "Menerbitkan sertifikat SSL untuk ${WB}$DOMAIN${NC} ..."
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt 2>/dev/null
/root/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" \
    --keylength ec-256 --httpport 80 --force 2>/dev/null

if [[ $? -eq 0 ]]; then
    /root/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
        --ecc \
        --key-file "$SSL_DIR/xray.key" \
        --fullchain-file "$SSL_DIR/xray.crt" \
        --reloadcmd "systemctl restart xray nginx 2>/dev/null" 2>/dev/null
    chmod 600 "$SSL_DIR/xray.key"
    log_ok "SSL Certificate untuk $DOMAIN berhasil!"
else
    log_fail "Gagal menerbitkan SSL! Pastikan domain sudah mengarah ke IP server."
    log_warn "Membuat self-signed certificate sebagai fallback..."
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout "$SSL_DIR/xray.key" -out "$SSL_DIR/xray.crt" \
        -days 365 -nodes -subj "/CN=$DOMAIN" 2>/dev/null
    chmod 600 "$SSL_DIR/xray.key"
    log_warn "Self-signed cert dibuat. Ganti dengan Let's Encrypt nanti."
fi

# ════════════════════════════════════════════════════════════
#  STEP 5: XRAY CONFIGURATION
# ════════════════════════════════════════════════════════════
STEP=5
log_step "$STEP/$TOTAL_STEPS" "KONFIGURASI XRAY"
echo ""

mkdir -p "$XRAY_DIR"

# Generate xray config from template
if [[ -f /etc/proxmaster/config/xray.json.tpl ]]; then
    cp /etc/proxmaster/config/xray.json.tpl "$XRAY_DIR/config.json"
else
    cat > "$XRAY_DIR/config.json" << XRAYCFG
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "api": {
    "tag": "api",
    "services": ["StatsService"]
  },
  "inbounds": [
    {
      "tag": "api",
      "port": 62731,
      "listen": "127.0.0.1",
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"}
    },
    {
      "tag": "vmess-ws-tls",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {"clients": [], "fallbacks": [{"dest": 3001}]},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vmess-ws", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "vmess-ws-ntls",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {"clients": []},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vmess-ntls", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "vless-ws-tls",
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {"clients": [], "decryption": "none", "fallbacks": [{"dest": 3003}]},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless-ws", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "vless-ws-ntls",
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {"clients": [], "decryption": "none"},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless-ntls", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "vless-grpc-tls",
      "port": 10005,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {"clients": [], "decryption": "none", "fallbacks": [{"dest": 3005}]},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "vless-grpc"}
      }
    },
    {
      "tag": "trojan-ws-tls",
      "port": 10006,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {"clients": [], "fallbacks": [{"dest": 3006}]},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/trojan-ws", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "trojan-grpc-tls",
      "port": 10007,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {"clients": [], "fallbacks": [{"dest": 3007}]},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "trojan-grpc"}
      }
    },
    {
      "tag": "ss-ws-tls",
      "port": 10008,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": {"clients": [], "fallbacks": [{"dest": 3008}]},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/ss-ws", "headers": {"Host": "$DOMAIN"}}
      }
    },
    {
      "tag": "ss-grpc-tls",
      "port": 10009,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": {"clients": [], "fallbacks": [{"dest": 3009}]},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "ss-grpc"}
      }
    }
  ],
  "outbounds": [
    {"tag": "direct", "protocol": "freedom"},
    {"tag": "block", "protocol": "blackhole"}
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"type": "field", "outboundTag": "block", "ip": ["geoip:private"]},
      {"type": "field", "outboundTag": "block", "domain": ["geosite:private"]}
    ]
  },
  "stats": {},
  "policy": {
    "levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}}
  }
}
XRAYCFG
fi

log_ok "Xray config dibuat di $XRAY_DIR/config.json"

# Xray systemd service
cat > /etc/systemd/system/xray.service << 'EOSVC'
[Unit]
Description=Xray Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOSVC

# Xray log dir
mkdir -p /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

systemctl daemon-reload
systemctl enable xray 2>/dev/null
systemctl start xray 2>/dev/null
sleep 1
if systemctl is-active --quiet xray; then
    log_ok "Xray service berjalan"
else
    log_fail "Xray gagal start, cek: journalctl -u xray -n 20"
fi

# ════════════════════════════════════════════════════════════
#  STEP 6: NGINX CONFIGURATION
# ════════════════════════════════════════════════════════════
STEP=6
log_step "$STEP/$TOTAL_STEPS" "KONFIGURASI NGINX"
echo ""

# Remove default config
rm -f /etc/nginx/sites-enabled/default 2>/dev/null

cat > /etc/nginx/conf.d/xray.conf << NGINXCFG
# ─── PROXMASTER - Nginx Configuration ──────────────────────
# Domain: $DOMAIN

# --- NON-TLS (Port 80) ---
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # ACME Challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # VMess non-TLS
    location /vmess-ntls {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # VLess non-TLS
    location /vless-ntls {
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# --- TLS (Port 443) ---
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     $SSL_DIR/xray.crt;
    ssl_certificate_key $SSL_DIR/xray.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    # VMess WS+TLS
    location /vmess-ws {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # VLess WS+TLS
    location /vless-ws {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # VLess gRPC+TLS
    location /vless-grpc {
        grpc_pass grpc://127.0.0.1:10005;
        grpc_set_header Host \$host;
    }

    # Trojan WS+TLS
    location /trojan-ws {
        proxy_pass http://127.0.0.1:10006;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Trojan gRPC+TLS
    location /trojan-grpc {
        grpc_pass grpc://127.0.0.1:10007;
        grpc_set_header Host \$host;
    }

    # Shadowsocks WS+TLS
    location /ss-ws {
        proxy_pass http://127.0.0.1:10008;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Shadowsocks gRPC+TLS
    location /ss-grpc {
        grpc_pass grpc://127.0.0.1:10009;
        grpc_set_header Host \$host;
    }
}
NGINXCFG

# Fix variable expansion in nginx config (dollar signs)
sed -i 's/\$http_upgrade/\$http_upgrade/g; s/\$host/\$host/g; s/\$remote_addr/\$remote_addr/g; s/\$proxy_add_x_forwarded_for/\$proxy_add_x_forwarded_for/g' /etc/nginx/conf.d/xray.conf

mkdir -p /var/www/html
echo "OK" > /var/www/html/index.html

nginx -t 2>/dev/null
if [[ $? -eq 0 ]]; then
    systemctl enable nginx 2>/dev/null
    systemctl restart nginx 2>/dev/null
    log_ok "Nginx dikonfigurasi dan berjalan"
else
    log_fail "Nginx config error! Cek: nginx -t"
fi

# ════════════════════════════════════════════════════════════
#  STEP 7: SSH-WS / SSH-SSL (STUNNEL + PYTHON WS)
# ════════════════════════════════════════════════════════════
STEP=7
log_step "$STEP/$TOTAL_STEPS" "INSTALL SSH-WS & SSH-SSL"
echo ""

# --- 7a. Download Python WS scripts from repo ---
WS_OPENSSH_PORT=2093
WS_DROPBEAR_PORT=2095
WS_STUNNEL_LOCAL_PORT=700
STUNNEL_SSL_PORT=445

ASSET_BASE="https://raw.githubusercontent.com/chanelog/xray/main/addon/files"
FILES_TMP=$(mktemp -d)

log_info "Mendownload WebSocket scripts ..."

fetch_asset() {
    local remote="$1" local_path="$2" desc="$3"
    echo -ne "  ${C}[*]${NC} $desc ... "
    if wget -q --timeout=30 "$ASSET_BASE/$remote" -O "$local_path" && [[ -s "$local_path" ]]; then
        echo -e "${G}OK${NC}"; return 0
    else
        echo -e "${R}GAGAL${NC}"; rm -f "$local_path"; return 1
    fi
}

FETCH_OK=true
fetch_asset "ws-openssh"              "$FILES_TMP/ws-openssh"              "ws-openssh"              || FETCH_OK=false
fetch_asset "ws-dropbear"             "$FILES_TMP/ws-dropbear"             "ws-dropbear"             || FETCH_OK=false
fetch_asset "ws-stunnel"              "$FILES_TMP/ws-stunnel"              "ws-stunnel"              || FETCH_OK=false
fetch_asset "ws-openssh.service.tpl"  "$FILES_TMP/ws-openssh.service.tpl"  "ws-openssh service"      || FETCH_OK=false
fetch_asset "ws-dropbear.service.tpl" "$FILES_TMP/ws-dropbear.service.tpl" "ws-dropbear service"     || FETCH_OK=false
fetch_asset "ws-stunnel.service.tpl"  "$FILES_TMP/ws-stunnel.service.tpl"  "ws-stunnel service"      || FETCH_OK=false

if [[ "$FETCH_OK" != "true" ]]; then
    log_warn "Beberapa file gagal didownload dari repo. Membuat fallback scripts ..."

    # --- Fallback: Create ws-openssh ---
    cat > "$FILES_TMP/ws-openssh" << 'PYEOF'
#!/usr/bin/env python3
import sys, socket, struct, os, signal, select, hashlib, base64, threading
try:
    import http.server, socketserver
except ImportError:
    print("ERROR: http.server module not available", file=sys.stderr); sys.exit(1)

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 22
WS_OPENSSH_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 2093
BACKEND_HOST = DEFAULT_HOST
BACKEND_PORT = DEFAULT_PORT
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

class WSHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() != "websocket":
            self.send_error(400); return
        key = self.headers.get("Sec-WebSocket-Key", "")
        accept = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
        xrh = self.headers.get("X-Real-Host", "")
        host_parts = xrh.split(":") if xrh else []
        if len(host_parts) == 2:
            BACKEND_HOST, BACKEND_PORT = host_parts[0], int(host_parts[1])
        elif xrh:
            BACKEND_HOST, BACKEND_PORT = xrh, DEFAULT_PORT
        self.send_response(101)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self._ws_loop()

    def _ws_loop(self):
        client = self.connection
        backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        backend.connect((BACKEND_HOST, BACKEND_PORT))
        bufs = {client: b"", backend: b""}
        try:
            while True:
                r, _, _ = select.select([client, backend], [], [], 3600)
                if not r: break
                for s in r:
                    try:
                        data = s.recv(65536)
                        if not data: raise ConnectionError("EOF")
                        if s is client:
                            for frame in self._decode_frames(data):
                                backend.sendall(frame)
                        else:
                            client.sendall(self._encode_frame(data))
                    except: return
        except: pass
        finally:
            try: backend.close()
            except: pass

    def _decode_frames(self, data):
        frames, i = [], 0
        while i < len(data):
            if i + 2 > len(data): break
            b1, b2 = data[i], data[i+1]; i += 2
            fin = (b1 >> 7) & 1; opcode = b1 & 0xf; masked = (b2 >> 7) & 1
            length = b2 & 0x7f; mask_key = None
            if length == 126:
                if i + 2 > len(data): break
                length = struct.unpack(">H", data[i:i+2])[0]; i += 2
            elif length == 127:
                if i + 8 > len(data): break
                length = struct.unpack(">Q", data[i:i+8])[0]; i += 8
            if masked:
                if i + 4 > len(data): break
                mask_key = data[i:i+4]; i += 4
            if i + length > len(data): break
            payload = bytearray(data[i:i+length]); i += length
            if masked and mask_key:
                for j in range(len(payload)): payload[j] ^= mask_key[j % 4]
            if opcode == 8: return frames
            if opcode in (1, 2) and payload: frames.append(bytes(payload))
        return frames

    def _encode_frame(self, data):
        b1 = 0x82; length = len(data); header = bytearray()
        if length < 126: header.append(b1); header.append(length)
        elif length < 65536: header += bytearray([b1, 126]) + struct.pack(">H", length)
        else: header += bytearray([b1, 127]) + struct.pack(">Q", length)
        return bytes(header) + data

    def log_message(self, fmt, *args): pass

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", WS_OPENSSH_PORT), WSHandler)
    signal.signal(signal.SIGTERM, lambda *_: (server.shutdown(), sys.exit(0)))
    server.serve_forever()
PYEOF

    # --- Fallback: Create ws-dropbear ---
    cp "$FILES_TMP/ws-openssh" "$FILES_TMP/ws-dropbear"
    sed -i 's/DEFAULT_PORT = 22/DEFAULT_PORT = 109/' "$FILES_TMP/ws-dropbear"

    # --- Fallback: Create ws-stunnel ---
    cp "$FILES_TMP/ws-openssh" "$FILES_TMP/ws-stunnel"
    sed -i 's/DEFAULT_PORT = 22/DEFAULT_PORT = 88/' "$FILES_TMP/ws-stunnel"

    # --- Fallback: Create service templates ---
    for svc in ws-openssh ws-dropbear ws-stunnel; do
        local_port_var=""
        case "$svc" in
            ws-openssh)  local_port_var="$WS_OPENSSH_PORT" ;;
            ws-dropbear) local_port_var="$WS_DROPBEAR_PORT" ;;
            ws-stunnel)  local_port_var="$WS_STUNNEL_LOCAL_PORT" ;;
        esac
        cat > "$FILES_TMP/${svc}.service.tpl" << SVCEOF
[Unit]
Description=SSH Over Websocket Python ($svc)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -O /usr/local/bin/${svc} ${local_port_var}
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SVCEOF
    done
fi

# --- 7b. Install Python WS scripts ---
install -m 755 "$FILES_TMP/ws-openssh"  /usr/local/bin/ws-openssh
install -m 755 "$FILES_TMP/ws-dropbear" /usr/local/bin/ws-dropbear
install -m 755 "$FILES_TMP/ws-stunnel"  /usr/local/bin/ws-stunnel
log_ok "WebSocket scripts terinstall"

# --- 7c. Create systemd services ---
PYTHON_BIN=$(command -v python3)

render_service() {
    local tpl="$1" out="$2"
    sed -e "s#__PYTHON_BIN__#$PYTHON_BIN#g" \
        -e "s#__WS_OPENSSH_PORT__#$WS_OPENSSH_PORT#g" \
        -e "s#__WS_DROPBEAR_PORT__#$WS_DROPBEAR_PORT#g" \
        -e "s#__WS_STUNNEL_LOCAL_PORT__#$WS_STUNNEL_LOCAL_PORT#g" \
        "$tpl" > "$out"
}

render_service "$FILES_TMP/ws-openssh.service.tpl"  /etc/systemd/system/ws-openssh.service
render_service "$FILES_TMP/ws-dropbear.service.tpl" /etc/systemd/system/ws-dropbear.service
render_service "$FILES_TMP/ws-stunnel.service.tpl"  /etc/systemd/system/ws-stunnel.service

rm -rf "$FILES_TMP"
systemctl daemon-reload
log_ok "Systemd services dibuat"

# --- 7d. Configure Stunnel4 ---
log_info "Mengkonfigurasi Stunnel4 ..."

if [[ -f "$SSL_DIR/xray.crt" && -f "$SSL_DIR/xray.key" ]]; then
    cat "$SSL_DIR/xray.crt" "$SSL_DIR/xray.key" > /etc/stunnel/stunnel.pem 2>/dev/null
else
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/stunnel.key -out /tmp/stunnel.crt \
        -days 365 -nodes -subj "/CN=${DOMAIN:-localhost}" 2>/dev/null
    cat /tmp/stunnel.crt /tmp/stunnel.key > /etc/stunnel/stunnel.pem
    rm -f /tmp/stunnel.key /tmp/stunnel.crt
fi
chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf << STUNCFG
pid = /var/run/stunnel4.pid

[ssh-ssl]
accept = $STUNNEL_SSL_PORT
connect = 127.0.0.1:$WS_STUNNEL_LOCAL_PORT
cert = /etc/stunnel/stunnel.pem
STUNCFG

sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
grep -q "^ENABLED=" /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" >> /etc/default/stunnel4
log_ok "Stunnel4 dikonfigurasi (port $STUNNEL_SSL_PORT -> 127.0.0.1:$WS_STUNNEL_LOCAL_PORT)"

# ════════════════════════════════════════════════════════════
#  STEP 8: INSTALL WSTUNNEL (RUST BINARY)
# ════════════════════════════════════════════════════════════
STEP=8
log_step "$STEP/$TOTAL_STEPS" "INSTALL WSTUNNEL (RUST BINARY)"
echo ""

WSTUNNEL_PORT=8880
case "$ARCH" in
    x86_64)  WST_ARCH="x86_64" ;;
    aarch64) WST_ARCH="aarch64" ;;
esac

WST_URL="https://github.com/erebe/wstunnel/releases/latest/download/wstunnel-linux-${WST_ARCH}.tar.gz"

log_info "Mendownload wstunnel ($WST_ARCH) ..."
if wget -q --timeout=60 "$WST_URL" -O /tmp/wstunnel.tar.gz 2>/dev/null; then
    tar -xzf /tmp/wstunnel.tar.gz -C /tmp/ 2>/dev/null
    install -m 755 /tmp/wstunnel "$BIN_DIR/wstunnel" 2>/dev/null || \
    install -m 755 /tmp/wstunnel-linux-*/wstunnel "$BIN_DIR/wstunnel" 2>/dev/null || \
    find /tmp -name "wstunnel" -type f -exec install -m 755 {} "$BIN_DIR/wstunnel" \;
    rm -f /tmp/wstunnel.tar.gz
    if [[ -x "$BIN_DIR/wstunnel" ]]; then
        log_ok "wstunnel terinstall di $BIN_DIR/wstunnel"
    else
        log_warn "wstunnel binary tidak ditemukan setelah extract"
    fi
else
    log_warn "Gagal download wstunnel, SSH-WS via wstunnel tidak tersedia"
fi

# Create proxy--ws service (wstunnel wrapper)
cat > /usr/local/bin/proxy--ws << 'PROXYEOF'
#!/bin/bash
exec /usr/local/bin/wstunnel client --connectToUnix /tmp/ssh.sock ws://127.0.0.1:22 &
SOCKPID=$!
/usr/local/bin/wstunnel server ws://0.0.0.0:8880 --socket $SOCKPID
PROXYEOF
chmod +x /usr/local/bin/proxy--ws 2>/dev/null

# Proper wstunnel service
if [[ -x "$BIN_DIR/wstunnel" ]]; then
    socat UNIX-LISTEN:/tmp/ssh.sock,fork TCP:127.0.0.1:22 &

    cat > /etc/systemd/system/proxy--ws.service << 'WSEOS'
[Unit]
Description=wstunnel SSH-WS Proxy (Rust)
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/socat UNIX-LISTEN:/tmp/ssh.sock,fork TCP:127.0.0.1:22
ExecStart=/usr/local/bin/wstunnel server ws://0.0.0.0:8880
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
WSEOS
    systemctl daemon-reload
    systemctl enable proxy--ws 2>/dev/null
fi

# ════════════════════════════════════════════════════════════
#  STEP 9: FIREWALL
# ════════════════════════════════════════════════════════════
STEP=9
log_step "$STEP/$TOTAL_STEPS" "FIREWALL CONFIGURATION"
echo ""

SSH_PORTS=(22 109 143 442 2093 2095 445 8880)
WEB_PORTS=(80 443)

for port in "${SSH_PORTS[@]}" "${WEB_PORTS[@]}"; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
done

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null

# Persist iptables
if ! command -v iptables-persistent &>/dev/null; then
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections 2>/dev/null
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections 2>/dev/null
    apt-get install -y -qq iptables-persistent 2>/dev/null
fi

log_ok "Firewall ports dibuka"

# ════════════════════════════════════════════════════════════
#  STEP 10: SETUP SCRIPT FILES & START ALL SERVICES
# ════════════════════════════════════════════════════════════
STEP=10
log_step "$STEP/$TOTAL_STEPS" "FINALISASI & START ALL SERVICES"
echo ""

# Setup script directory
mkdir -p "$SCRIPT_DIR/db"
mkdir -p "$SCRIPT_DIR/menu"
mkdir -p "$SCRIPT_DIR/addon"
mkdir -p "$SCRIPT_DIR/addon/files"
mkdir -p "$SCRIPT_DIR/config"

# Copy all script files from the installer's directory
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
for f in lib.sh menu.sh VERSION; do
    [[ -f "$INSTALL_DIR/$f" ]] && cp "$INSTALL_DIR/$f" "$SCRIPT_DIR/$f"
done
for f in menu/*.sh; do
    [[ -f "$INSTALL_DIR/$f" ]] && cp "$INSTALL_DIR/$f" "$SCRIPT_DIR/$f"
done
for f in addon/*.sh; do
    [[ -f "$INSTALL_DIR/$f" ]] && cp "$INSTALL_DIR/$f" "$SCRIPT_DIR/$f"
done

chmod +x "$SCRIPT_DIR/menu.sh" "$SCRIPT_DIR/menu"/*.sh "$SCRIPT_DIR/addon"/*.sh 2>/dev/null

# Save domain
cp /tmp/proxmaster_domain.tmp "$SCRIPT_DIR/domain"
rm -f /tmp/proxmaster_domain.tmp

# Save version
echo "1.0.0" > "$SCRIPT_DIR/VERSION"

# Create 'proxmaster' command alias
if ! grep -q "proxmaster" /root/.bashrc 2>/dev/null; then
    echo -e '\n# ProxMaster VPN Suite\nalias proxmaster="bash /etc/proxmaster/menu.sh"' >> /root/.bashrc
    export -f proxmaster 2>/dev/null
fi
# Also create a symlink for direct command
ln -sf "$SCRIPT_DIR/menu.sh" "$BIN_DIR/proxmaster" 2>/dev/null
chmod +x "$BIN_DIR/proxmaster" 2>/dev/null

# Create empty databases
touch "$SCRIPT_DIR/db/vmess.db" "$SCRIPT_DIR/db/vless.db" \
      "$SCRIPT_DIR/db/trojan.db" "$SCRIPT_DIR/db/ss.db" \
      "$SCRIPT_DIR/db/ssh.db"

# Start all services
ALL_SERVS=(xray nginx dropbear ws-openssh ws-dropbear ws-stunnel stunnel4 proxy--ws)
echo ""
echo -e "  ${CB}════════════════════════════════════════════${NC}"
echo -e "  ${WB}  STARTING ALL SERVICES${NC}"
echo -e "  ${CB}════════════════════════════════════════════${NC}"
echo ""

for svc in "${ALL_SERVS[@]}"; do
    echo -ne "  ${C}[*]${NC} $svc ... "
    systemctl enable "$svc" 2>/dev/null
    systemctl restart "$svc" 2>/dev/null
    sleep 0.3
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GB}RUNNING${NC}"
    else
        echo -e "${RB}STOPPED${NC}"
    fi
done

# ════════════════════════════════════════════════════════════
#  INSTALLATION COMPLETE
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GB}  ╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GB}  ║${NC}                                                          ${GB}║${NC}"
echo -e "${GB}  ║${NC}     ${WB}INSTALLASI PROXMASTER BERHASIL!${NC}                    ${GB}║${NC}"
echo -e "${GB}  ║${NC}                                                          ${GB}║${NC}"
echo -e "${GB}  ╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CB}Domain${NC}           : ${WB}$DOMAIN${NC}"
echo -e "  ${CB}Xray${NC}             : $(systemctl is-active --quiet xray && echo -e "${GB}RUNNING${NC}" || echo -e "${RB}STOPPED${NC}")"
echo -e "  ${CB}Nginx${NC}            : $(systemctl is-active --quiet nginx && echo -e "${GB}RUNNING${NC}" || echo -e "${RB}STOPPED${NC}")"
echo -e "  ${CB}Stunnel4${NC}         : $(systemctl is-active --quiet stunnel4 && echo -e "${GB}RUNNING${NC}" || echo -e "${RB}STOPPED${NC}") (port $STUNNEL_SSL_PORT)"
echo -e "  ${CB}SSH-WS (OpenSSH)${NC}  : $(systemctl is-active --quiet ws-openssh && echo -e "${GB}RUNNING${NC}" || echo -e "${RB}STOPPED${NC}") (port $WS_OPENSSH_PORT)"
echo -e "  ${CB}SSH-WS (Dropbear)${NC} : $(systemctl is-active --quiet ws-dropbear && echo -e "${GB}RUNNING${NC}" || echo -e "${RB}STOPPED${NC}") (port $WS_DROPBEAR_PORT)"
echo -e "  ${CB}wstunnel${NC}         : $(systemctl is-active --quiet proxy--ws 2>/dev/null && echo -e "${GB}RUNNING${NC}" || echo -e "${Y}NOT INSTALLED${NC}") (port $WSTUNNEL_PORT)"
echo ""
echo -e "  ${CB}Port Mapping:${NC}"
echo -e "    80/443           ${D}->${NC} Xray (VMess/VLess/Trojan/SS) via Nginx"
echo -e "    2093             ${D}->${NC} SSH-WS (OpenSSH)"
echo -e "    2095             ${D}->${NC} SSH-WS (Dropbear)"
echo -e "    445              ${D}->${NC} SSH-SSL (Stunnel4 -> ws-stunnel)"
echo -e "    8880             ${D}->${NC} SSH-WS (wstunnel/Rust)"
echo ""
echo -e "  ${YB}Ketik 'proxmaster' untuk membuka menu manajemen.${NC}"
echo ""