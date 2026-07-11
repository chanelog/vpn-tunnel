#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - ADDON: SSH-WS/SSH-SSL INSTALLER
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; W='\033[0;37m'; NC='\033[0m'
RB='\033[1;31m'; GB='\033[1;32m'; YB='\033[1;33m'; CB='\033[1;36m'; WB='\033[1;37m'

log_ok()   { echo -e "  ${G}[OK]${NC} $1"; }
log_fail() { echo -e "  ${R}[FAIL]${NC} $1"; }
log_info() { echo -e "  ${C}[*]${NC} $1"; }
log_warn() { echo -e "  ${Y}[!]${NC} $1"; }

[[ $EUID -ne 0 ]] && { echo -e "${RB}[ERROR]${NC} Jalankan sebagai root!"; exit 1; }

DOMAIN=$(get_domain)

clear
echo -e "${CB}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CB}║${NC}  ${WB}INSTALL ADDON: SSH-WS (OpenSSH/Dropbear) + SSH-SSL${NC}       ${CB}║${NC}"
echo -e "${CB}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Clean old ws-proxy ──────────────────────────────────
log_info "Membersihkan instalasi SSH-WS lama ..."
systemctl stop ws-proxy 2>/dev/null; systemctl disable ws-proxy 2>/dev/null
rm -f /etc/systemd/system/ws-proxy.service /usr/local/bin/ws-proxy.py
systemctl daemon-reload 2>/dev/null
log_ok "Bersih"

# ─── 2. Dependencies ────────────────────────────────────────
log_info "Install dependensi ..."
apt-get update -qq 2>/dev/null
apt-get install -y -qq stunnel4 python3 2>/dev/null
PYTHON_BIN=$(command -v python3)
log_ok "Dependensi OK (python3: $PYTHON_BIN)"

# ─── 3. Download or create WS scripts ───────────────────────
ASSET_BASE="https://raw.githubusercontent.com/chanelog/xray/main/addon/files"
FILES_TMP=$(mktemp -d)

log_info "Mendownload WebSocket scripts dari repo ..."

fetch_ok=true
for f in ws-openssh ws-dropbear ws-stunnel ws-openssh.service.tpl ws-dropbear.service.tpl ws-stunnel.service.tpl; do
    echo -ne "  ${C}[*]${NC} $f ... "
    if wget -q --timeout=30 "$ASSET_BASE/$f" -O "$FILES_TMP/$f" && [[ -s "$FILES_TMP/$f" ]]; then
        echo -e "${G}OK${NC}"
    else
        echo -e "${Y}GAGAL${NC}"; rm -f "$FILES_TMP/$f"; fetch_ok=false
    fi
done

if [[ "$fetch_ok" != "true" ]]; then
    log_warn "Download gagal, membuat fallback scripts ..."
    cat > "$FILES_TMP/ws-openssh" << 'PYEOF'
#!/usr/bin/env python3
import sys, socket, struct, hashlib, base64, select, signal, http.server
DEFAULT_HOST="127.0.0.1"; DEFAULT_PORT=22; GUID="258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Upgrade","").lower()!="websocket": self.send_error(400); return
        k=self.headers.get("Sec-WebSocket-Key","")
        a=base64.b64encode(hashlib.sha1((k+GUID).encode()).digest()).decode()
        xrh=self.headers.get("X-Real-Host",""); hp=xrh.split(":") if xrh else []
        bh,bp=(hp[0],int(hp[1])) if len(hp)==2 else (DEFAULT_HOST,DEFAULT_PORT) if not xrh else (xrh,DEFAULT_PORT)
        self.send_response(101); self.send_header("Upgrade","websocket")
        self.send_header("Connection","Upgrade"); self.send_header("Sec-WebSocket-Accept",a); self.end_headers()
        c=self.connection; b=socket.socket(); b.connect((bh,bp))
        try:
            while True:
                r,_,_=select.select([c,b],[],[],3600)
                if not r: break
                for s in r:
                    try:
                        d=s.recv(65536)
                        if not d: return
                        if s is c:
                            for fr in self._df(d): b.sendall(fr)
                        else: c.sendall(self._ef(d))
                    except: return
        except: pass
        finally:
            try: b.close()
            except: pass
    def _df(self,data):
        fs=[]; i=0
        while i<len(data):
            if i+2>len(data): break
            b1,b2=data[i],data[i+1]; i+=2; op=b1&0xf; mk=(b2>>7)&1; ln=b2&0x7f; msk=None
            if ln==126:
                if i+2>len(data): break; ln=struct.unpack(">H",data[i:i+2])[0]; i+=2
            elif ln==127:
                if i+8>len(data): break; ln=struct.unpack(">Q",data[i:i+8])[0]; i+=8
            if mk:
                if i+4>len(data): break; msk=data[i:i+4]; i+=4
            if i+ln>len(data): break; pl=bytearray(data[i:i+ln]); i+=ln
            if msk and msk:
                for j in range(len(pl)): pl[j]^=msk[j%4]
            if op==8: return fs
            if op in(1,2) and pl: fs.append(bytes(pl))
        return fs
    def _ef(self,data):
        ln=len(data); h=bytearray([0x82])
        if ln<126: h.append(ln)
        elif ln<65536: h+=bytearray([126])+struct.pack(">H",ln)
        else: h+=bytearray([127])+struct.pack(">Q",ln)
        return bytes(h)+data
    def log_message(self,*a): pass
if __name__=="__main__":
    p=int(sys.argv[1]) if len(sys.argv)>1 else 2093
    s=http.server.HTTPServer(("0.0.0.0",p),H)
    signal.signal(signal.SIGTERM,lambda *_:(s.shutdown(),sys.exit(0)))
    s.serve_forever()
PYEOF

    cp "$FILES_TMP/ws-openssh" "$FILES_TMP/ws-dropbear"
    sed -i 's/DEFAULT_PORT=22/DEFAULT_PORT=109/' "$FILES_TMP/ws-dropbear"
    cp "$FILES_TMP/ws-openssh" "$FILES_TMP/ws-stunnel"
    sed -i 's/DEFAULT_PORT=22/DEFAULT_PORT=88/' "$FILES_TMP/ws-stunnel"

    for svc in ws-openssh ws-dropbear ws-stunnel; do
        local_port="$WS_OPENSSH_PORT"
        [[ "$svc" == "ws-dropbear" ]] && local_port="$WS_DROPBEAR_PORT"
        [[ "$svc" == "ws-stunnel" ]] && local_port="$WS_STUNNEL_LOCAL_PORT"
        cat > "$FILES_TMP/${svc}.service.tpl" << SVCEOF
[Unit]
Description=SSH Over Websocket Python (${svc})
After=network.target
[Service]
Type=simple
ExecStart=__PYTHON_BIN__ -O /usr/local/bin/${svc} ${local_port}
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
SVCEOF
    done
fi

# ─── 4. Install binaries ────────────────────────────────────
install -m 755 "$FILES_TMP/ws-openssh"  /usr/local/bin/ws-openssh
install -m 755 "$FILES_TMP/ws-dropbear" /usr/local/bin/ws-dropbear
install -m 755 "$FILES_TMP/ws-stunnel"  /usr/local/bin/ws-stunnel
log_ok "WebSocket scripts terinstall"

# ─── 5. Render & install services ───────────────────────────
render_svc() {
    sed -e "s#__PYTHON_BIN__#$PYTHON_BIN#g" \
        -e "s#__WS_OPENSSH_PORT__#$WS_OPENSSH_PORT#g" \
        -e "s#__WS_DROPBEAR_PORT__#$WS_DROPBEAR_PORT#g" \
        -e "s#__WS_STUNNEL_LOCAL_PORT__#$WS_STUNNEL_LOCAL_PORT#g" \
        "$1" > "$2"
}

render_svc "$FILES_TMP/ws-openssh.service.tpl"  /etc/systemd/system/ws-openssh.service
render_svc "$FILES_TMP/ws-dropbear.service.tpl" /etc/systemd/system/ws-dropbear.service
render_svc "$FILES_TMP/ws-stunnel.service.tpl"  /etc/systemd/system/ws-stunnel.service
rm -rf "$FILES_TMP"
systemctl daemon-reload
log_ok "Systemd services dibuat"

# ─── 6. Stunnel4 config ─────────────────────────────────────
log_info "Konfigurasi Stunnel4 ..."

if [[ -f /etc/ssl/xray/xray.crt && -f /etc/ssl/xray/xray.key ]]; then
    cat /etc/ssl/xray/xray.crt /etc/ssl/xray/xray.key > /etc/stunnel/stunnel.pem 2>/dev/null
else
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/st.key -out /tmp/st.crt \
        -days 365 -nodes -subj "/CN=${DOMAIN:-localhost}" 2>/dev/null
    cat /tmp/st.crt /tmp/st.key > /etc/stunnel/stunnel.pem
    rm -f /tmp/st.key /tmp/st.crt
fi
chmod 600 /etc/stunnel/stunnel.pem

# Remove old [ssh-ssl] block if exists
if grep -q "\[ssh-ssl\]" /etc/stunnel/stunnel.conf 2>/dev/null; then
    awk '/^\[ssh-ssl\]/{skip=1;next} /^\[/&&skip{skip=0} !skip{print}' \
        /etc/stunnel/stunnel.conf > /tmp/st.conf.new
    cp /tmp/st.conf.new /etc/stunnel/stunnel.conf
    rm -f /tmp/st.conf.new
fi

# Ensure pid line exists at top
if ! grep -q "^pid\s*=" /etc/stunnel/stunnel.conf 2>/dev/null; then
    sed -i '1i pid = /var/run/stunnel4.pid' /etc/stunnel/stunnel.conf
fi

cat >> /etc/stunnel/stunnel.conf << EOF2

[ssh-ssl]
accept = $STUNNEL_SSL_PORT
connect = 127.0.0.1:$WS_STUNNEL_LOCAL_PORT
cert = /etc/stunnel/stunnel.pem
EOF2

sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
grep -q "^ENABLED=" /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" >> /etc/default/stunnel4
log_ok "Stunnel4: $STUNNEL_SSL_PORT -> 127.0.0.1:$WS_STUNNEL_LOCAL_PORT"

# ─── 7. Clean old nginx /ssh-ws ─────────────────────────────
NGINX_CONF="/etc/nginx/conf.d/xray.conf"
if [[ -f "$NGINX_CONF" ]] && grep -q "ssh-ws" "$NGINX_CONF"; then
    log_info "Membersihkan location /ssh-ws lama di Nginx ..."
    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%s)"
    python3 - "$NGINX_CONF" << 'PYCLEAN'
import re, sys
path=sys.argv[1]
with open(path) as f: text=f.read()
def rm_blocks(t, pat):
    out, i = [], 0; p = re.compile(pat)
    while True:
        m = p.search(t, i)
        if not m: out.append(t[i:]); break
        out.append(t[i:m.start()])
        d, j = 0, m.end()-1
        while j < len(t):
            if t[j] == '{': d += 1
            elif t[j] == '}':
                d -= 1
                if d == 0: j += 1; break
            j += 1
        i = j
    return "".join(out)
text = rm_blocks(text, r'location\s+/ssh-ws\s*\{')
text = re.sub(r'\n{3,}', '\n\n', text)
with open(path, "w") as f: f.write(text)
PYCLEAN
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null
        log_ok "Nginx dibersihkan"
    else
        cp "${NGINX_CONF}.bak.$(date +%s)" "$NGINX_CONF" 2>/dev/null
        log_fail "nginx -t gagal, config dikembalikan"
    fi
fi

# ─── 8. Firewall ────────────────────────────────────────────
log_info "Membuka port firewall ..."
for port in $WS_OPENSSH_PORT $WS_DROPBEAR_PORT $STUNNEL_SSL_PORT; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
done
mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4 2>/dev/null
log_ok "Firewall OK"

# ─── 9. Start all ───────────────────────────────────────────
echo ""
log_info "Mengaktifkan semua service ..."
for svc in ws-openssh ws-dropbear ws-stunnel stunnel4; do
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

echo ""
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "${GB}  ADDON SSH-WS / SSH-SSL BERHASIL DIINSTALL${NC}"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo -e "  SSH-WS (OpenSSH)  : $DOMAIN : $WS_OPENSSH_PORT"
echo -e "  SSH-WS (Dropbear) : $DOMAIN : $WS_DROPBEAR_PORT"
echo -e "  SSH-SSL           : $DOMAIN : $STUNNEL_SSL_PORT  (stunnel4)"
echo -e "${GB}  ══════════════════════════════════════════════════${NC}"
echo ""
echo -ne "  ${D}Tekan Enter untuk kembali...${NC}"; read -r