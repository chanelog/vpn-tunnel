#!/bin/bash
# ============================================================
#   PROXMASTER - CHANGE DOMAIN
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

clear
box_top "GANTI DOMAIN"
box_empty
echo -e "    ${W}Domain saat ini${NC}: ${WB}$(get_domain)${NC}"
echo ""
echo -ne "    ${WB}Domain baru${NC}: "
read -r new_domain
new_domain=$(echo "$new_domain" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

[[ -z "$new_domain" ]] && { echo -e "  ${R}Domain kosong!${NC}"; press_enter; exit 1; }

if ! echo "$new_domain" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
    echo -e "  ${R}Format tidak valid!${NC}"; press_enter; exit 1
fi

echo ""
echo -e "  ${C}[*]${NC} Memverifikasi DNS ..."
SERVER_IP=$(get_server_ip)
DOMAIN_IP=$(dig +short "$new_domain" A 2>/dev/null | grep -E '^[0-9]+\.' | tail -1)

if [[ -n "$DOMAIN_IP" && "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "  ${Y}[!]${NC} Domain -> $DOMAIN_IP, Server -> $SERVER_IP (tidak cocok)"
    echo -ne "  Lanjutkan? [y/N]: "; read -r c
    [[ ! "$c" =~ ^[Yy]$ ]] && { press_enter; exit 0; }
fi

echo -e "  ${C}[*]${NC} Mengganti domain ke ${WB}${new_domain}${NC} ..."
change_domain "$new_domain"

echo ""
echo -e "  ${G}Domain berhasil diganti ke ${WB}${new_domain}${NC}"
press_enter