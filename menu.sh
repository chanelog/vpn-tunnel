#!/bin/bash
# ============================================================
#   PROXMASTER VPN SUITE - MAIN MENU
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

main_menu() {
    while true; do
        clear

        # ─── Header ────────────────────────────────────────
        local domain=$(get_domain)
        local ip=$(get_server_ip)
        local xv=$(get_xray_version)

        # Status collection
        local xray_st nginx_st drop_st stun_st
        local wso_st wsd_st wss_st wst_st hap_st

        xray_st=$(status_dot xray)
        nginx_st=$(status_dot nginx)
        drop_st=$(status_dot dropbear)
        stun_st=$(status_dot stunnel4)
        wso_st=$(status_dot ws-openssh)
        wsd_st=$(status_dot ws-dropbear)
        wss_st=$(status_dot ws-stunnel)
        wst_st=$(status_dot proxy--ws)
        hap_st=$(status_dot haproxy)

        local total=$(( $(count_vmess) + $(count_vless) + $(count_trojan) + $(count_ss) + $(count_ssh) ))

        # ─── Render ────────────────────────────────────────
        echo ""
        echo -e "${CB}  ┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
        echo -e "${CB}  │${NC}     ${WB}P R O X M A S T E R${NC}                              ${CB}│${NC}"
        echo -e "${CB}  │${NC}     ${D}Advanced VPN Tunnel Manager${NC}                          ${CB}│${NC}"
        echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
        echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CB}  │${NC}  ${W}Domain${NC}  ${D}..${NC}  ${WB}${domain}${NC}$(printf '%*s' $((28 - ${#domain})) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  ${W}IP${NC}      ${D}..${NC}  ${W}${ip}${NC}$(printf '%*s' $((28 - ${#ip})) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CB}  │${NC}  Xray            ${xray_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  Nginx           ${nginx_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  Stunnel4        ${stun_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  ws-openssh      ${wso_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  ws-dropbear     ${wsd_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  HAProxy         ${hap_st}${NC}$(printf '%*s' $((28 - 20)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  │${NC}  ${W}Total Akun${NC}     ${YB}${total}${NC}$(printf '%*s' $((28 - 14)) '' | tr ' ' ' ')${CB}│${NC}"
        echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${GB}[1]${NC}  ${W}Kelola Xray${NC} ${D}(VMess/VLess/Trojan/SS)${NC}         ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${GB}[2]${NC}  ${W}Kelola SSH / SSH-WS / SSH-SSL${NC}                 ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${GB}[3]${NC}  ${W}Kelola Services${NC}                                  ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${GB}[4]${NC}  ${W}System Info${NC}                                      ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${GB}[5]${NC}  ${W}Ganti Domain${NC}                                     ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${YB}[6]${NC}  ${W}Update Script${NC}                                    ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${RB}[7]${NC}  ${W}Uninstall${NC}                                        ${CB}│${NC}"
        echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
        echo -e "${CB}  │${NC}    ${D}[0]  Keluar${NC}                                            ${CB}│${NC}"
        echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
        echo -e "${CB}  └──────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -ne "    ${WB}Pilih [0-7]${NC}: "
        read -r choice

        case "$choice" in
            1) bash "$SCRIPT_DIR/menu/xray.sh" ;;
            2) bash "$SCRIPT_DIR/menu/sshws.sh" ;;
            3) bash "$SCRIPT_DIR/menu/services.sh" ;;
            4) bash "$SCRIPT_DIR/menu/sysinfo.sh" ;;
            5) bash "$SCRIPT_DIR/menu/changedomain.sh" ;;
            6) bash "$SCRIPT_DIR/menu/update.sh" ;;
            7) bash "$SCRIPT_DIR/menu/uninstall.sh" ;;
            0) clear; echo -e "  ${D}Terima kasih. Goodbye!${NC}"; echo ""; exit 0 ;;
            *) echo -e "  ${R}Pilihan tidak valid${NC}"; sleep 1 ;;
        esac
    done
}

main_menu