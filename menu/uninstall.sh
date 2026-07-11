#!/bin/bash
# ============================================================
#   PROXMASTER - UNINSTALL
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

clear
echo -e "  ${RB}══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${RB}║${NC}                                                          ${RB}║${NC}"
echo -e "  ${RB}║${NC}     ${WB}U N I N S T A L L   P R O X M A S T E R${NC}                ${RB}║${NC}"
echo -e "  ${RB}║${NC}                                                          ${RB}║${NC}"
echo -e "  ${RB}║${NC}  ${R}PERINGATAN: Semua data akun dan konfigurasi${NC}               ${RB}║${NC}"
echo -e "  ${RB}║${NC}  ${R}akan dihapus permanen!${NC}                                 ${RB}║${NC}"
echo -e "  ${RB}║${NC}                                                          ${RB}║${NC}"
echo -e "  ${RB}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -ne "  ${WB}Ketik 'HAPUS' untuk konfirmasi${NC}: "
read -r c
[[ "$c" != "HAPUS" ]] && { echo -e "  ${Y}Dibatalkan${NC}"; press_enter; return; }

echo ""
echo -e "  ${C}[*]${NC} Menghentikan semua service ..."
for svc in "${MANAGED_SERVICES[@]}"; do
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
done

echo -e "  ${C}[*]${NC} Menghapus service files ..."
for svc in xray ws-openssh ws-dropbear ws-stunnel proxy--ws; do
    rm -f "/etc/systemd/system/${svc}.service"
done
rm -f /etc/systemd/system/haproxy.service 2>/dev/null
systemctl daemon-reload

echo -e "  ${C}[*]${NC} Menghapus packages ..."
apt-get remove -y -qq xray stunnel4 dropbear haproxy 2>/dev/null
apt-get autoremove -y -qq 2>/dev/null

echo -e "  ${C}[*]${NC} Menghapus file ..."
rm -rf "$SCRIPT_DIR"
rm -rf /etc/xray
rm -rf /usr/local/bin/ws-openssh /usr/local/bin/ws-dropbear
rm -rf /usr/local/bin/ws-stunnel /usr/local/bin/proxy--ws
rm -rf /usr/local/bin/xray /usr/local/bin/wstunnel
rm -rf /etc/stunnel/stunnel.conf /etc/stunnel/stunnel.pem
rm -f /etc/nginx/conf.d/xray.conf

# Remove bash completion
rm -f /etc/bash_completion.d/proxmaster 2>/dev/null
sed -i '/proxmaster/d' /root/.bashrc 2>/dev/null

echo ""
echo -e "  ${G}ProxMaster berhasil diuninstall${NC}"
echo -e "  ${D}Nginx dan SSL certificate tetap ada.${NC}"
press_enter