#!/bin/bash
# ============================================================
#   PROXMASTER - UPDATE SCRIPT
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

clear
box_top "UPDATE SCRIPT"
box_empty

local_v=$(get_local_version)
remote_v=$(get_remote_version)

box_row "Versi Lokal" "$local_v"
box_row "Versi Remote" "${remote_v:-N/A}"
box_empty

if [[ -z "$remote_v" ]]; then
    echo -e "  ${R}Tidak bisa cek versi remote${NC}"
    press_enter; return
fi

if [[ "$local_v" == "$remote_v" ]]; then
    echo -e "  ${G}Script sudah versi terbaru!${NC}"
    press_enter; return
fi

echo -e "  ${YB}Update tersedia: $local_v -> $remote_v${NC}"
echo ""
echo -ne "  ${WB}Update sekarang? [Y/n]${NC}: "
read -r c
[[ "$c" =~ ^[Nn]$ ]] && { press_enter; return; }

echo ""
echo -e "  ${C}[*]${NC} Mengupdate file ..."

UPDATE_FILES=(
    "lib.sh" "menu.sh" "menu/xray.sh" "menu/sshws.sh" "menu/services.sh"
    "menu/sysinfo.sh" "menu/changedomain.sh" "menu/uninstall.sh" "menu/update.sh"
    "addon/install-sshws.sh" "addon/install-haproxy.sh" "addon/install-wstunnel.sh"
)

UPDATE_RAW="https://raw.githubusercontent.com/chanelog/xray/main"

for f in "${UPDATE_FILES[@]}"; do
    echo -ne "  ${C}[*]${NC} $f ... "
    local tmp
    tmp=$(mktemp)
    if wget -q --timeout=30 "$UPDATE_RAW/$f" -O "$tmp" && [[ -s "$tmp" ]]; then
        mkdir -p "$(dirname "$SCRIPT_DIR/$f")"
        cp "$tmp" "$SCRIPT_DIR/$f"
        chmod +x "$SCRIPT_DIR/$f" 2>/dev/null
        rm -f "$tmp"
        echo -e "${G}OK${NC}"
    else
        echo -e "${Y}SKIP${NC}"
        rm -f "$tmp"
    fi
done

echo "$remote_v" > "$SCRIPT_DIR/VERSION"
echo ""
echo -e "  ${G}Update selesai ke versi $remote_v${NC}"
press_enter