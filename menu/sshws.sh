#!/bin/bash
# ============================================================
#   PROXMASTER - SSH / SSH-WS / SSH-SSL MANAGEMENT
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

sshws_addon_missing() {
    [[ ! -f /usr/local/bin/ws-openssh ]] || \
    [[ ! -f /usr/local/bin/ws-dropbear ]] || \
    [[ ! -f /usr/local/bin/ws-stunnel ]] || \
    ! is_service_installed stunnel4
}

is_haproxy_installed() {
    is_service_installed haproxy && [[ -f /etc/haproxy/haproxy.cfg ]]
}

sshws_header() {
    clear
    local domain=$(get_domain)
    local count=$(count_ssh)

    box_top "SSH / SSH-WS / SSH-SSL"
    box_row "Domain" "$domain"
    box_mid
    box_row "Dropbear"   "$(status_dot dropbear)"
    box_row "Stunnel4"   "$(status_dot stunnel4)"
    box_row "ws-openssh" "$(status_dot ws-openssh)  ${D}port $WS_OPENSSH_PORT${NC}"
    box_row "ws-dropbear" "$(status_dot ws-dropbear)  ${D}port $WS_DROPBEAR_PORT${NC}"
    box_row "ws-stunnel" "$(status_dot ws-stunnel)"
    box_row "wstunnel"   "$(status_dot proxy--ws)  ${D}port $WSTUNNEL_PORT${NC}"
    box_row "HAProxy"    "$(status_dot haproxy)"
    box_mid
    box_row_color "SSH Direct"    "port 442, 109, 143" "W"
    box_row_color "SSH-SSL"       "port $STUNNEL_SSL_PORT (stunnel4)" "W"
    box_row_color "SSH-WS OpenSSH" "port $WS_OPENSSH_PORT" "W"
    box_row_color "SSH-WS Dropbear" "port $WS_DROPBEAR_PORT" "W"
    if systemctl is-active --quiet haproxy; then
        box_row_color "SSH-SSL via 443" "SNI routing (HAProxy)" "MB"
    fi
    box_row "Total Akun" "$count"
    box_bot
}

sshws_menu() {
    if sshws_addon_missing; then
        clear
        box_top "ADDON SSH-WS BELUM TERINSTALL"
        box_empty
        echo -e "    ${W}Fitur SSH-WS/SSH-SSL butuh komponen tambahan${NC}"
        echo -e "    ${W}(stunnel4 + ws-openssh/ws-dropbear/ws-stunnel).${NC}"
        echo ""
        echo -ne "    ${WB}Install sekarang? [Y/n]${NC}: "
        read -r c
        if [[ ! "$c" =~ ^[Nn]$ ]]; then
            bash "$SCRIPT_DIR/addon/install-sshws.sh"
        fi
        return
    fi

    while true; do
        sshws_header
        echo ""
        box_menu_item "1" "Buat Akun SSH"
        box_menu_item "2" "Info Akun SSH"
        box_menu_item "3" "Detail Koneksi"
        box_menu_item "4" "Hapus Akun SSH"
        box_menu_item "5" "Perpanjang Akun SSH"
        box_menu_item "6" "Daftar Semua Akun"
        if is_haproxy_installed; then
            box_menu_item "7" "Kelola HAProxy"
        else
            box_menu_item "7" "Aktifkan SSH-SSL via 443 (HAProxy)"
        fi
        echo ""
        box_menu_item_dim "0" "Kembali"
        echo ""
        echo -ne "    ${WB}Pilih [0-7]${NC}: "
        read -r c
        case "$c" in
            1) _ssh_create ;;
            2) _ssh_info ;;
            3) _ssh_detail ;;
            4) _ssh_delete ;;
            5) _ssh_renew ;;
            6) _ssh_list ;;
            7) _haproxy_menu ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_ssh_create() {
    sshws_header
    echo ""
    echo -ne "    ${WB}Username${NC}    : "; read -r user
    [[ -z "$user" ]] && { echo -e "  ${R}Kosong!${NC}"; press_enter; return; }
    grep -q "^${user}|" "$DB_SSH" && { echo -e "  ${R}Sudah ada!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Password${NC}    : "; read -r pass
    echo -ne "    ${WB}Masa aktif${NC}  : "; read -r days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Harus angka!${NC}"; press_enter; return; }

    local real_pass=$(create_ssh "$user" "$days" "$pass")
    local domain=$(get_domain)
    local exp=$(get_exp_date "$days")

    clear
    box_top "AKUN SSH DIBUAT"
    box_row "Username" "$user"
    box_row "Password" "$real_pass"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp ($days hari)"
    box_mid
    box_row_color "SSH Direct"       "port 442/109/143" "W"
    box_row_color "SSH-SSL"          "port $STUNNEL_SSL_PORT TLS:ON" "W"
    box_row_color "SSH-WS (OpenSSH)" "port $WS_OPENSSH_PORT" "W"
    box_row_color "SSH-WS (Dropbear)" "port $WS_DROPBEAR_PORT" "W"
    box_row_color "SSH-WS (wstunnel)" "port $WSTUNNEL_PORT" "W"
    if systemctl is-active --quiet haproxy; then
        box_row_color "SSH-SSL via 443"  "port 443 SNI: !domain" "MB"
    fi
    box_mid
    box_row "Payload WS" "$(ws_payload_string "$domain")"
    box_bot
    press_enter
}

_ssh_info() {
    sshws_header
    echo ""
    echo -ne "    ${WB}Username${NC}: "; read -r user
    local info=$(get_ssh_info "$user")
    [[ -z "$info" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }

    local pass=$(echo "$info" | cut -d'|' -f2)
    local exp=$(echo "$info"  | cut -d'|' -f3)
    local r=$(days_until_exp "$exp")
    local sc="${GB}" st="AKTIF"
    [[ $r -lt 0 ]] && { sc="${RB}"; st="EXPIRED"; }
    [[ $r -le 3 && $r -ge 0 ]] && { sc="${YB}"; st="SEGERA EXPIRED"; }

    box_top "INFO AKUN SSH"
    box_row "Username" "$user"
    box_row "Password" "$pass"
    box_row "Expired" "$exp"
    box_row "Sisa" "$r hari"
    box_row_color "Status" "$st" "sc"
    box_bot
    press_enter
}

_ssh_detail() {
    sshws_header
    echo ""
    echo -ne "    ${WB}Username${NC}: "; read -r user
    local info=$(get_ssh_info "$user")
    [[ -z "$info" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }

    local pass=$(echo "$info" | cut -d'|' -f2)
    local exp=$(echo "$info"  | cut -d'|' -f3)
    local domain=$(get_domain)

    clear
    box_top "DETAIL KONEKSI SSH"
    box_row "Username" "$user"
    box_row "Password" "$pass"
    box_row "Domain" "$domain"
    box_row "Expired" "$exp"
    box_mid
    echo -e "    ${GB}[1] SSH Direct${NC}          : ${W}${domain} port 442 / 109 / 143${NC}"
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    echo -e "    ${GB}[2] SSH-SSL (Stunnel)${NC}   : ${W}${domain} port $STUNNEL_SSL_PORT TLS:ON${NC}"
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    echo -e "    ${GB}[3] SSH-WS (OpenSSH)${NC}    : ${W}${domain} port $WS_OPENSSH_PORT${NC}"
    echo -e "    ${Y}    Payload: $(ws_payload_string "$domain")${NC}"
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    echo -e "    ${GB}[4] SSH-WS (Dropbear)${NC}   : ${W}${domain} port $WS_DROPBEAR_PORT${NC}"
    echo -e "    ${Y}    Payload: $(ws_payload_string "$domain")${NC}"
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    echo -e "    ${GB}[5] SSH-WS (wstunnel)${NC}    : ${W}${domain} port $WSTUNNEL_PORT${NC}"
    if systemctl is-active --quiet haproxy; then
        echo -e "    ${C}──────────────────────────────────────────────────${NC}"
        echo -e "    ${MB}[6] SSH-SSL via 443${NC}     : ${W}${domain} port 443${NC}"
        echo -e "    ${Y}    SNI: apa saja SELAIN '$domain'${NC}"
    fi
    box_bot
    press_enter
}

_ssh_delete() {
    sshws_header
    echo ""
    _list_ssh_simple
    echo ""
    echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_ssh_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${R}Hapus '$user'? [y/N]${NC}: "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { delete_ssh "$user"; echo -e "  ${G}Dihapus!${NC}"; press_enter; return; }
    press_enter
}

_ssh_renew() {
    sshws_header
    echo ""
    _list_ssh_simple
    echo ""
    echo -ne "    ${WB}Username${NC}: "; read -r user
    [[ -z "$(get_ssh_info "$user")" ]] && { echo -e "  ${R}Tidak ditemukan!${NC}"; press_enter; return; }
    echo -ne "    ${WB}Perpanjang (hari)${NC}: "; read -r days; days=${days:-30}
    renew_ssh "$user" "$days"
    echo -e "  ${G}Diperpanjang hingga $(get_exp_date "$days")${NC}"
    press_enter
}

_ssh_list() {
    clear
    box_top "DAFTAR AKUN SSH"
    box_empty
    _list_ssh_simple
    press_enter
}

_list_ssh_simple() {
    local count=0
    echo -e "    ${CB}$(printf '%-18s %-14s %-12s %-8s' "USERNAME" "PASSWORD" "EXPIRED" "STATUS")${NC}"
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    while IFS='|' read -r user pass exp created; do
        [[ -z "$user" ]] && continue
        local r=$(days_until_exp "$exp") c="${W}" st="AKTIF"
        [[ $r -lt 0 ]] && { c="${R}"; st="EXPIRED"; }
        [[ $r -le 3 && $r -ge 0 ]] && { c="${Y}"; st="EXPIRED SOON"; }
        printf "    ${c}%-18s %-14s %-12s %-8s${NC}\n" "$user" "$pass" "$exp" "$st"
        ((count++))
    done < <(list_ssh)
    echo -e "    ${C}──────────────────────────────────────────────────${NC}"
    echo -e "    ${YB}Total${NC}: ${WB}${count}${NC} akun"
}

# ════════════════════════════════════════════════════════════
#  HAPROXY SUBMENU
# ════════════════════════════════════════════════════════════
_haproxy_menu() {
    clear
    box_top "HAPROXY SNI ROUTER"
    box_row "Status" "$(status_dot haproxy)"
    box_row "Config" "/etc/haproxy/haproxy.cfg"
    box_empty
    box_menu_item "1" "Restart HAProxy"
    box_menu_item "2" "Install Ulang Config"
    box_menu_item "3" "Copot HAProxy (Nginx kembali ke 443)"
    box_empty
    box_menu_item_dim "0" "Kembali"
    box_bot
    echo ""
    echo -ne "    ${WB}Pilih [0-3]${NC}: "
    read -r c
    case "$c" in
        1)
            systemctl restart haproxy
            echo -e "  ${G}HAProxy di-restart${NC}"; press_enter
            ;;
        2)
            bash "$SCRIPT_DIR/addon/install-haproxy.sh"
            ;;
        3)
            echo -ne "  ${R}Yakin copot HAProxy? [y/N]${NC}: "; read -r c
            if [[ "$c" =~ ^[Yy]$ ]]; then
                systemctl stop haproxy 2>/dev/null
                systemctl disable haproxy 2>/dev/null
                NGINX_CONF="/etc/nginx/conf.d/xray.conf"
                if [[ -f "$NGINX_CONF" ]] && grep -q "listen 127.0.0.1:${NGINX_TLS_INTERNAL_PORT} ssl http2;" "$NGINX_CONF"; then
                    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%s)"
                    sed -i "s/listen 127.0.0.1:${NGINX_TLS_INTERNAL_PORT} ssl http2;/listen 443 ssl http2;\n    listen [::]:443 ssl http2;/" "$NGINX_CONF"
                    if nginx -t 2>/dev/null; then
                        systemctl reload nginx 2>/dev/null
                        echo -e "  ${G}HAProxy dicopot, Nginx kembali ke 443${NC}"
                    else
                        echo -e "  ${R}nginx -t gagal${NC}"
                    fi
                fi
            fi
            press_enter
            ;;
        0) return ;;
    esac
    sshws_menu
}

sshws_menu