#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - ADDON: HAProxy SNI ROUTER
#   Makes SSH-SSL accessible on port 443 via SNI routing
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; W='\033[0;37m'; NC='\033[0m'
GB='\033[1;32m'; RB='\033[1;31m'; WB='\033[1;37m'; CB='\033[1;36m'

[[ $EUID -ne 0 ]] && { echo -e "${RB}[ERROR]${NC} Root required!"; exit 1; }

DOMAIN=$(get_domain)
NGINX_CONF="/etc/nginx/conf.d/xray.conf"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

clear
echo -e "${CB}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CB}║${NC}  ${WB}HAPROXY SNI ROUTER - SSH-SSL VIA PORT 443${NC}              ${CB}║${NC}"
echo -e "${CB}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${W}Fitur:${NC} SSH-SSL bisa diakses lewat port 443"
echo -e "  ${W}SNI routing:${NC}"
echo -e "    ${G}SNI = $DOMAIN${NC}       -> Nginx (Xray)"
echo -e "    ${Y}SNI = lain/kosong${NC}   -> Stunnel4 (SSH-SSL)"
echo ""

# ─── 1. Install HAProxy ────────────────────────────────────
echo -e "  ${C}[*]${NC} Install HAProxy ..."
apt-get update -qq 2>/dev/null
apt-get install -y -qq haproxy 2>/dev/null
echo -e "  ${G}[OK]${NC} HAProxy terinstall"

# ─── 2. Move Nginx to loopback ─────────────────────────────
echo -e "  ${C}[*]${NC} Menggeser Nginx dari 443 -> 127.0.0.1:$NGINX_TLS_INTERNAL_PORT ..."

if [[ -f "$NGINX_CONF" ]]; then
    BACKUP="${NGINX_CONF}.bak.$(date +%s)"
    cp "$NGINX_CONF" "$BACKUP"

    # Replace listen 443 ssl http2 with loopback
    sed -i "s/listen 443 ssl http2;/listen 127.0.0.1:${NGINX_TLS_INTERNAL_PORT} ssl http2;/" "$NGINX_CONF"
    sed -i "s/listen \[::\]:443 ssl http2;/# IPv6 disabled (behind HAProxy)/" "$NGINX_CONF"

    # Remove any existing listen on the internal port to avoid duplicates
    # Then validate
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null
        echo -e "  ${G}[OK]${NC} Nginx digeser ke 127.0.0.1:$NGINX_TLS_INTERNAL_PORT"
    else
        cp "$BACKUP" "$NGINX_CONF"
        echo -e "  ${R}[FAIL]${NC} nginx -t gagal, config dikembalikan"
        exit 1
    fi
else
    echo -e "  ${Y}[!]${NC} $NGINX_CONF tidak ditemukan"
fi

# ─── 3. Create HAProxy config ──────────────────────────────
echo -e "  ${C}[*]${NC} Membuat konfigurasi HAProxy ..."

cat > "$HAPROXY_CFG" << HAPCFG
# ═══════════════════════════════════════════════════════════
# PROXMASTER - HAProxy SNI Router
# Port 443 -> Nginx/Xray (SNI=$DOMAIN) or Stunnel4 (SNI!=domain)
# ═══════════════════════════════════════════════════════════

global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  300s
    timeout server  300s
    retries 3

# ─── Frontend: Port 443 (SNI-based routing) ──────────────
frontend ssl_front
    bind *:443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    # SNI matches domain -> Xray/Nginx
    acl is_xray req_ssl_sni -i $DOMAIN
    use_backend xray_nginx if is_xray

    # Default: everything else -> Stunnel4 (SSH-SSL)
    default_backend stunnel_ssh

# ─── Backend: Xray/Nginx (TLS passthrough) ────────────────
backend xray_nginx
    server nginx 127.0.0.1:$NGINX_TLS_INTERNAL_PORT

# ─── Backend: Stunnel4 (SSH-SSL) ──────────────────────────
backend stunnel_ssh
    server stunnel 127.0.0.1:$STUNNEL_SSL_PORT
HAPCFG

echo -e "  ${G}[OK]${NC} HAProxy config dibuat"

# ─── 4. Enable and start ──────────────────────────────────
echo -e "  ${C}[*]${NC} Menjalankan HAProxy ..."
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/haproxy 2>/dev/null

systemctl daemon-reload
systemctl enable haproxy 2>/dev/null
systemctl restart haproxy 2>/dev/null
sleep 1

if systemctl is-active --quiet haproxy; then
    echo -e "  ${G}[OK]${NC} HAProxy ${GB}RUNNING${NC} di port 443"
else
    echo -e "  ${R}[FAIL]${NC} HAProxy gagal start. Cek: journalctl -u haproxy -n 20"
fi

echo ""
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "${GB}  HAPROXY SNI ROUTER TERPASANG${NC}"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "  Port 443 sekarang:"
echo -e "    SNI = $DOMAIN   ${D}->${NC} Xray (VMess/VLess/Trojan/SS)"
echo -e "    SNI != $DOMAIN  ${D}->${NC} Stunnel4 (SSH-SSL)"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo ""
echo -ne "  ${D}Tekan Enter untuk kembali...${NC}"; read -r