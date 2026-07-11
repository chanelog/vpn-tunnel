#!/bin/bash
# ============================================================
#   PROXMASTER - SERVICE MANAGEMENT
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

services_menu() {
    while true; do
        clear
        box_top "KELOLA SERVICES"
        for svc in "${MANAGED_SERVICES[@]}"; do
            local dot
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                dot="${GB}●${NC} ${W}${svc}${NC}"
            else
                dot="${RB}●${NC} ${D}${svc}${NC}"
            fi
            echo -e "    ${C}│${NC}  $dot $(printf '%*s' $((42 - ${#svc})) '' | tr ' ' ' ') ${C}│${NC}"
        done
        box_bot
        echo ""
        box_menu_item "1" "Start Semua Service"
        box_menu_item "2" "Stop Semua Service"
        box_menu_item "3" "Restart Semua Service"
        box_menu_item "4" "Toggle Individual Service"
        box_empty
        box_menu_item_dim "0" "Kembali"
        echo ""
        echo -ne "    ${WB}Pilih [0-4]${NC}: "
        read -r c
        case "$c" in
            1) _start_all ;;
            2) _stop_all ;;
            3) _restart_all ;;
            4) _toggle_one ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

_start_all() {
    for svc in "${MANAGED_SERVICES[@]}"; do
        echo -ne "  ${C}[*]${NC} Starting $svc ... "
        systemctl start "$svc" 2>/dev/null
        sleep 0.2
        systemctl is-active --quiet "$svc" && echo -e "${GB}OK${NC}" || echo -e "${RB}FAIL${NC}"
    done
    press_enter
}

_stop_all() {
    echo -ne "  ${R}Stop ALL services? [y/N]${NC}: "; read -r c
    [[ ! "$c" =~ ^[Yy]$ ]] && return
    for svc in "${MANAGED_SERVICES[@]}"; do
        systemctl stop "$svc" 2>/dev/null
    done
    echo -e "  ${G}Semua service di-stop${NC}"
    press_enter
}

_restart_all() {
    for svc in "${MANAGED_SERVICES[@]}"; do
        echo -ne "  ${C}[*]${NC} Restarting $svc ... "
        systemctl restart "$svc" 2>/dev/null
        sleep 0.3
        systemctl is-active --quiet "$svc" && echo -e "${GB}OK${NC}" || echo -e "${RB}FAIL${NC}"
    done
    press_enter
}

_toggle_one() {
    clear
    box_top "TOGGLE SERVICE"
    box_empty
    local i=1
    local svcs=()
    for svc in "${MANAGED_SERVICES[@]}"; do
        local st
        systemctl is-active --quiet "$svc" && st="${GB}RUNNING${NC}" || st="${RB}STOPPED${NC}"
        box_menu_item "$i" "$svc  $st"
        svcs+=("$svc")
        ((i++))
    done
    box_empty
    box_menu_item_dim "0" "Kembali"
    box_bot
    echo ""
    echo -ne "    ${WB}Pilih service [0-$((i-1))]${NC}: "
    read -r n
    [[ "$n" == "0" || -z "$n" || "$n" -lt 1 || "$n" -ge $i ]] && return
    local target="${svcs[$((n-1))]}"
    if systemctl is-active --quiet "$target"; then
        systemctl stop "$target"
        echo -e "  ${Y}$target dihentikan${NC}"
    else
        systemctl start "$target"
        echo -e "  ${G}$target dijalankan${NC}"
    fi
    press_enter
}

services_menu