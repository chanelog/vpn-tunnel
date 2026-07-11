#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - ADDON: WSTUNNEL (RUST) INSTALLER
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; W='\033[0;37m'; NC='\033[0m'
GB='\033[1;32m'; RB='\033[1;31m'; WB='\033[1;37m'; CB='\033[1;36m'

[[ $EUID -ne 0 ]] && { echo -e "${RB}[ERROR]${NC} Root required!"; exit 1; }

clear
echo -e "${CB}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CB}║${NC}  ${WB}INSTALL WSTUNNEL (RUST) - SSH-WS BINARY${NC}                    ${CB}║${NC}"
echo -e "${CB}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Detect arch ────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  WST_ARCH="x86_64" ;;
    aarch64) WST_ARCH="aarch64" ;;
    *)       echo -e "  ${R}[ERROR]${NC} Arsitektur $ARCH tidak didukung"; exit 1 ;;
esac

# ─── 2. Install socat ──────────────────────────────────────
apt-get install -y -qq socat 2>/dev/null

# ─── 3. Download wstunnel ─────────────────────────────────
WST_URL="https://github.com/erebe/wstunnel/releases/latest/download/wstunnel-linux-${WST_ARCH}.tar.gz"

echo -e "  ${C}[*]${NC} Mendownload wstunnel ($WST_ARCH) ..."
if wget -q --timeout=60 "$WST_URL" -O /tmp/wstunnel.tar.gz 2>/dev/null; then
    mkdir -p /tmp/wstunnel_extract
    tar -xzf /tmp/wstunnel.tar.gz -C /tmp/wstunnel_extract 2>/dev/null

    # Find the binary (different archive structures)
    WST_BIN=""
    if [[ -f /tmp/wstunnel_extract/wstunnel ]]; then
        WST_BIN="/tmp/wstunnel_extract/wstunnel"
    else
        WST_BIN=$(find /tmp/wstunnel_extract -name "wstunnel" -type f 2>/dev/null | head -1)
    fi

    if [[ -n "$WST_BIN" && -x "$WST_BIN" ]]; then
        install -m 755 "$WST_BIN" /usr/local/bin/wstunnel
        echo -e "  ${G}[OK]${NC} wstunnel terinstall di /usr/local/bin/wstunnel"
    else
        echo -e "  ${R}[FAIL]${NC} Binary tidak ditemukan setelah extract"
        rm -rf /tmp/wstunnel.tar.gz /tmp/wstunnel_extract
        exit 1
    fi

    rm -rf /tmp/wstunnel.tar.gz /tmp/wstunnel_extract
else
    echo -e "  ${R}[FAIL]${NC} Gagal download wstunnel"
    exit 1
fi

# ─── 4. Create systemd service ────────────────────────────
echo -e "  ${C}[*]${NC} Membuat service ..."

cat > /etc/systemd/system/proxy--ws.service << 'WSEOS'
[Unit]
Description=wstunnel SSH-WS Proxy (Rust binary)
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/socat UNIX-LISTEN:/tmp/ssh.sock,fork,reuseaddr TCP:127.0.0.1:22
ExecStart=/usr/local/bin/wstunnel server ws://0.0.0.0:8880 --socket /tmp/ssh.sock
ExecStopPost=-/bin/rm -f /tmp/ssh.sock
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
WSEOS

systemctl daemon-reload
systemctl enable proxy--ws 2>/dev/null
systemctl restart proxy--ws 2>/dev/null
sleep 1

if systemctl is-active --quiet proxy--ws; then
    echo -e "  ${G}[OK]${NC} proxy--ws ${GB}RUNNING${NC} di port $WSTUNNEL_PORT"
else
    echo -e "  ${Y}[!]${NC} proxy--ws gagal start. Cek: journalctl -u proxy--ws -n 20"
fi

# ─── 5. Firewall ────────────────────────────────────────────
iptables -C INPUT -p tcp --dport "$WSTUNNEL_PORT" -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport "$WSTUNNEL_PORT" -j ACCEPT 2>/dev/null
mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4 2>/dev/null

echo ""
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "${GB}  WSTUNNEL (RUST) TERINSTALL${NC}"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "  SSH-WS (wstunnel) : $(get_domain) port $WSTUNNEL_PORT"
echo -e "  Backend           : 127.0.0.1:22 (OpenSSH)"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo ""
echo -ne "  ${D}Tekan Enter untuk kembali...${NC}"; read -r