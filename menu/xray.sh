#!/bin/bash
# ============================================================
#   PROXMASTER - XRAY PROTOCOL MANAGEMENT MENU
#   VMess / VLess / Trojan / Shadowsocks
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

xray_menu() {
    while true; do
        clear
        local vm_c=$(count_vmess) vl_c=$(count_vless) tr_c=$(count_trojan) ss_c=$(count_ssh)

        box_top "KELOLA XRAY PROTOCOLS"
        box_row "VMess"       "$vm_c akun"
        box_row "VLess"       "$vl_c akun"
        box_row "Trojan"      "$tr_c akun"
        box_row "Shadowsocks" "$ss_c akun"
        box_empty
        box_menu_item "1" "VMess"
        box_menu_item "2" "VLess"
        box_menu_item "3" "Trojan"
        box_menu_item "4" "Shadowsocks"
        box_mid
        box_menu_item "5" "Hapus Semua Akun Expired"
        box_empty
        box_menu_item_dim "0" "Kembali"
        box_bot
        echo ""
        echo -ne "    ${WB}Pilih [0-5]${NC}: "
        read -r c
        case "$c" in
            1) vmess_sub ;;
            2) vless_sub ;;
            3) trojan_sub ;;
            4) ss_sub ;;
            5)
                delete_expired
                echo -e "\n  ${G}[OK]${NC} Akun expired dihapus"
                press_enter
                ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  VMESS
# ════════════════════════════════════════════════════════════
vmess_sub() {
    while true; do
        clear
        box_top "VMESS MANAGEMENT"
        box_row "Total Akun" "$(count_vmess)"
        box_empty
        box_menu_item "1" "Buat Akun VMess"
        box_menu_item "2" "Hapus Akun VMess"
        box_menu_item "3" "Perpanjang Akun"
        box_menu_item "4" "Daftar Akun"
        box_empty
        box_menu_item_dim "0" "Kembali"
        box_bot
        echo ""
        echo -ne "    ${WB}Pilih [0-4]${NC}: "
        read -r c
        case "$c" in
            1) _vmess_create ;;
            2) _vmess_delete ;;
            3) _vmess_renew ;;
            4) _vmess_list ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_vmess_create() {
    clear
    box_top "BUAT AKUN VMESS"
    box_empty
    echo -ne "    ${WB}Username${NC}    : "; read -r user
    [[ -z "$user" ]] && { echo -e "  ${R}Username kosong!${NC}"; press_enter; return; }
    grep -q "^${user}|" "$DB_VMESS" && { echo -e "  ${R}Sudah ada!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Masa aktif${NC}   : "; read -r days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Harus angka!${NC}"; press_enter; return; }

    local uuid=$(create_vmess "$user" "$days")
    local domain=$(get_domain)
    local exp=$(get_exp_date "$days")
    local link_tls=$(gen_vmess_link "$user" "$uuid" "$domain" "tls")
    local link_ntls=$(gen_vmess_link "$user" "$uuid" "$domain" "ntls")

    clear
    box_top "AKUN VMESS DIBUAT"
    box_row "Username" "$user"
    box_row "UUID" "$uuid"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp ($days hari)"
    box_mid
    box_row_color "VMess TLS" "Port 443" "GB"
    box_row_color "VMess non-TLS" "Port 80" "YB"
    box_bot
    echo ""
    echo -e "  ${CB}Link VMess TLS:${NC}"
    echo -e "  ${D}${link_tls}${NC}"
    echo ""
    echo -e "  ${CB}Link VMess non-TLS:${NC}"
    echo -e "  ${D}${link_ntls}${NC}"
    press_enter
}

_vmess_delete() {
    clear; box_top "HAPUS AKUN VMESS"; box_empty
    _list_db "$DB_VMESS" "VMess"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_vmess_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${R}Hapus '$user'? [y/N]${NC}: "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { delete_vmess "$user"; echo -e "  ${G}Dihapus!${NC}"; }
    press_enter
}

_vmess_renew() {
    clear; box_top "PERPANJANG VMESS"; box_empty
    _list_db "$DB_VMESS" "VMess"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    local info=$(get_vmess_info "$user")
    [[ -z "$info" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    local old_exp=$(echo "$info" | cut -d'|' -f3)
    echo -e "    ${W}Expired saat ini${NC}: $old_exp"
    echo -ne "    ${WB}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
    renew_vmess "$user" "$days"
    echo -e "  ${G}Diperpanjang hingga $(get_exp_date "$days")${NC}"
    press_enter
}

_vmess_list() {
    clear; box_top "DAFTAR AKUN VMESS"; box_empty
    _list_db "$DB_VMESS" "VMess"
    press_enter
}

# ════════════════════════════════════════════════════════════
#  VLESS
# ════════════════════════════════════════════════════════════
vless_sub() {
    while true; do
        clear
        box_top "VLESS MANAGEMENT"
        box_row "Total Akun" "$(count_vless)"
        box_empty
        box_menu_item "1" "Buat Akun VLess"
        box_menu_item "2" "Hapus Akun VLess"
        box_menu_item "3" "Perpanjang Akun"
        box_menu_item "4" "Daftar Akun"
        box_empty
        box_menu_item_dim "0" "Kembali"
        box_bot
        echo ""
        echo -ne "    ${WB}Pilih [0-4]${NC}: "
        read -r c
        case "$c" in
            1) _vless_create ;;
            2) _vless_delete ;;
            3) _vless_renew ;;
            4) _vless_list ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_vless_create() {
    clear; box_top "BUAT AKUN VLESS"; box_empty
    echo -ne "    ${WB}Username${NC}    : "; read -r user
    [[ -z "$user" ]] && { echo -e "  ${R}Kosong!${NC}"; press_enter; return; }
    grep -q "^${user}|" "$DB_VLESS" && { echo -e "  ${R}Sudah ada!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Masa aktif${NC}   : "; read -r days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Harus angka!${NC}"; press_enter; return; }

    local uuid=$(create_vless "$user" "$days")
    local domain=$(get_domain)
    local exp=$(get_exp_date "$days")
    local link_ws_tls=$(gen_vless_link "$user" "$uuid" "$domain" "tls")
    local link_ws_ntls=$(gen_vless_link "$user" "$uuid" "$domain" "ntls")
    local link_grpc=$(gen_vless_link "$user" "$uuid" "$domain" "grpc")

    clear
    box_top "AKUN VLESS DIBUAT"
    box_row "Username" "$user"
    box_row "UUID" "$uuid"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp ($days hari)"
    box_mid
    box_row_color "VLess WS+TLS"   "Port 443" "GB"
    box_row_color "VLess WS+nTLS"  "Port 80" "YB"
    box_row_color "VLess gRPC+TLS" "Port 443" "BB"
    box_bot
    echo ""
    echo -e "  ${CB}VLess WS+TLS:${NC} ${D}${link_ws_tls}${NC}"
    echo -e "  ${CB}VLess WS+nTLS:${NC} ${D}${link_ws_ntls}${NC}"
    echo -e "  ${CB}VLess gRPC:${NC} ${D}${link_grpc}${NC}"
    press_enter
}

_vless_delete() {
    clear; box_top "HAPUS AKUN VLESS"; box_empty
    _list_db "$DB_VLESS" "VLess"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_vless_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${R}Hapus '$user'? [y/N]${NC}: "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { delete_vless "$user"; echo -e "  ${G}Dihapus!${NC}"; }
    press_enter
}

_vless_renew() {
    clear; box_top "PERPANJANG VLESS"; box_empty
    _list_db "$DB_VLESS" "VLess"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_vless_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
    renew_vless "$user" "$days"
    echo -e "  ${G}Diperpanjang hingga $(get_exp_date "$days")${NC}"
    press_enter
}

_vless_list() {
    clear; box_top "DAFTAR AKUN VLESS"; box_empty
    _list_db "$DB_VLESS" "VLess"
    press_enter
}

# ════════════════════════════════════════════════════════════
#  TROJAN
# ════════════════════════════════════════════════════════════
trojan_sub() {
    while true; do
        clear
        box_top "TROJAN MANAGEMENT"
        box_row "Total Akun" "$(count_trojan)"
        box_empty
        box_menu_item "1" "Buat Akun Trojan"
        box_menu_item "2" "Hapus Akun Trojan"
        box_menu_item "3" "Perpanjang Akun"
        box_menu_item "4" "Daftar Akun"
        box_empty
        box_menu_item_dim "0" "Kembali"
        box_bot
        echo ""
        echo -ne "    ${WB}Pilih [0-4]${NC}: "
        read -r c
        case "$c" in
            1) _trojan_create ;;
            2) _trojan_delete ;;
            3) _trojan_renew ;;
            4) _trojan_list ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_trojan_create() {
    clear; box_top "BUAT AKUN TROJAN"; box_empty
    echo -ne "    ${WB}Username${NC}    : "; read -r user
    [[ -z "$user" ]] && { echo -e "  ${R}Kosong!${NC}"; press_enter; return; }
    grep -q "^${user}|" "$DB_TROJAN" && { echo -e "  ${R}Sudah ada!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Masa aktif${NC}   : "; read -r days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Harus angka!${NC}"; press_enter; return; }

    local pass=$(create_trojan "$user" "$days")
    local domain=$(get_domain)
    local exp=$(get_exp_date "$days")
    local link_ws=$(gen_trojan_link "$user" "$pass" "$domain" "ws")
    local link_grpc=$(gen_trojan_link "$user" "$pass" "$domain" "grpc")

    clear
    box_top "AKUN TROJAN DIBUAT"
    box_row "Username" "$user"
    box_row "Password" "$pass"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp ($days hari)"
    box_mid
    box_row_color "Trojan WS+TLS"  "Port 443" "GB"
    box_row_color "Trojan gRPC+TLS" "Port 443" "BB"
    box_bot
    echo ""
    echo -e "  ${CB}Trojan WS:${NC} ${D}${link_ws}${NC}"
    echo -e "  ${CB}Trojan gRPC:${NC} ${D}${link_grpc}${NC}"
    press_enter
}

_trojan_delete() {
    clear; box_top "HAPUS AKUN TROJAN"; box_empty
    _list_db "$DB_TROJAN" "Trojan"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_trojan_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${R}Hapus '$user'? [y/N]${NC}: "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { delete_trojan "$user"; echo -e "  ${G}Dihapus!${NC}"; }
    press_enter
}

_trojan_renew() {
    clear; box_top "PERPANJANG TROJAN"; box_empty
    _list_db "$DB_TROJAN" "Trojan"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_trojan_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
    renew_trojan "$user" "$days"
    echo -e "  ${G}Diperpanjang hingga $(get_exp_date "$days")${NC}"
    press_enter
}

_trojan_list() {
    clear; box_top "DAFTAR AKUN TROJAN"; box_empty
    _list_db "$DB_TROJAN" "Trojan"
    press_enter
}

# ════════════════════════════════════════════════════════════
#  SHADOWSOCKS
# ════════════════════════════════════════════════════════════
ss_sub() {
    while true; do
        clear
        box_top "SHADOWSOCKS MANAGEMENT"
        box_row "Total Akun" "$(count_ss)"
        box_empty
        box_menu_item "1" "Buat Akun Shadowsocks"
        box_menu_item "2" "Hapus Akun Shadowsocks"
        box_menu_item "3" "Perpanjang Akun"
        box_menu_item "4" "Daftar Akun"
        box_empty
        box_menu_item_dim "0" "Kembali"
        box_bot
        echo ""
        echo -ne "    ${WB}Pilih [0-4]${NC}: "
        read -r c
        case "$c" in
            1) _ss_create ;;
            2) _ss_delete ;;
            3) _ss_renew ;;
            4) _ss_list ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_ss_create() {
    clear; box_top "BUAT AKUN SHADOWSOCKS"; box_empty
    echo -ne "    ${WB}Username${NC}    : "; read -r user
    [[ -z "$user" ]] && { echo -e "  ${R}Kosong!${NC}"; press_enter; return; }
    grep -q "^${user}|" "$DB_SS" && { echo -e "  ${R}Sudah ada!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Masa aktif${NC}   : "; read -r days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Harus angka!${NC}"; press_enter; return; }

    local pass=$(create_ss "$user" "$days")
    local domain=$(get_domain)
    local exp=$(get_exp_date "$days")
    local link_ws=$(gen_ss_link "$user" "$pass" "$domain" "ws")
    local link_grpc=$(gen_ss_link "$user" "$pass" "$domain" "grpc")

    clear
    box_top "AKUN SHADOWSOCKS DIBUAT"
    box_row "Username" "$user"
    box_row "Password" "$pass"
    box_row "Method" "aes-128-gcm"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp ($days hari)"
    box_mid
    box_row_color "SS WS+TLS"    "Port 443" "GB"
    box_row_color "SS gRPC+TLS"  "Port 443" "BB"
    box_bot
    echo ""
    echo -e "  ${CB}SS WS:${NC} ${D}${link_ws}${NC}"
    echo -e "  ${CB}SS gRPC:${NC} ${D}${link_grpc}${NC}"
    press_enter
}

_ss_delete() {
    clear; box_top "HAPUS AKUN SHADOWSOCKS"; box_empty
    _list_db "$DB_SS" "Shadowsocks"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_ss_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${R}Hapus '$user'? [y/N]${NC}: "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { delete_ss "$user"; echo -e "  ${G}Dihapus!${NC}"; }
    press_enter
}

_ss_renew() {
    clear; box_top "PERPANJANG SHADOWSOCKS"; box_empty
    _list_db "$DB_SS" "Shadowsocks"
    echo ""; echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_ss_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
    renew_ss "$user" "$days"
    echo -e "  ${G}Diperpanjang hingga $(get_exp_date "$days")${NC}"
    press_enter
}

_ss_list() {
    clear; box_top "DAFTAR AKUN SHADOWSOCKS"; box_empty
    _list_db "$DB_SS" "Shadowsocks"
    press_enter
}

# ════════════════════════════════════════════════════════════
#  HELPER: LIST DATABASE
# ════════════════════════════════════════════════════════════
_list_db() {
    local db="$1" label="$2"
    local count=0
    echo -e "    ${CB}$(printf '%-18s %-14s %-12s' "USERNAME" "KEY" "EXPIRED")${NC}"
    echo -e "    ${C}─────────────────────────────────────────${NC}"
    while IFS='|' read -r user key exp created; do
        [[ -z "$user" ]] && continue
        local r=$(days_until_exp "$exp") c="${W}"
        [[ $r -lt 0 ]] && c="${R}"
        [[ $r -le 3 && $r -ge 0 ]] && c="${Y}"
        printf "    ${c}%-18s %-14s %-12s${NC}\n" "$user" "${key:0:12}..." "$exp"
        ((count++))
    done < <(cat "$db" 2>/dev/null)
    echo -e "    ${C}─────────────────────────────────────────${NC}"
    echo -e "    ${YB}Total${NC}: ${WB}${count}${NC} akun"
}

xray_menu