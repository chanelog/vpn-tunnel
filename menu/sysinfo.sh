#!/bin/bash
# ============================================================
#   PROXMASTER - SYSTEM INFO DASHBOARD
# ============================================================

SCRIPT_DIR="/etc/proxmaster"
source "$SCRIPT_DIR/lib.sh"

sysinfo_dashboard() {
    clear

    local domain=$(get_domain)
    local ip=$(get_server_ip)
    local os=$(get_os_info)
    local kernel=$(get_kernel)
    local uptime=$(get_uptime)
    local cpu_model=$(get_cpu_info)
    local cpu_cores=$(get_cpu_cores)
    local cpu_usage=$(get_cpu_usage)
    local mem=$(get_mem_usage)
    local disk=$(get_disk_usage)
    local net=$(get_network_usage)
    local load=$(get_load_avg)
    local xv=$(get_xray_version)

    echo ""
    echo -e "${CB}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CB}  │${NC}     ${WB}S Y S T E M   I N F O R M A T I O N${NC}                ${CB}│${NC}"
    echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Domain${NC}        ${D}..${NC}  ${WB}${domain}${NC}$(printf '%*s' $((26 - ${#domain})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Server IP${NC}     ${D}..${NC}  ${W}${ip}${NC}$(printf '%*s' $((26 - ${#ip})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}OS${NC}            ${D}..${NC}  ${W}${os}${NC}$(printf '%*s' $((26 - ${#os})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Kernel${NC}        ${D}..${NC}  ${W}${kernel}${NC}$(printf '%*s' $((26 - ${#kernel})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Uptime${NC}        ${D}..${NC}  ${W}${uptime}${NC}$(printf '%*s' $((26 - ${#uptime})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
    echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CB}  │${NC}  ${W}CPU${NC}            ${D}..${NC}  ${W}${cpu_cores} core(s)${NC}$(printf '%*s' $((24 - ${#cpu_cores})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}CPU Model${NC}     ${D}..${NC}  ${D}${cpu_model:0:36}${NC}$(printf '%*s' $((36 - ${#cpu_model:0:36})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}CPU Usage${NC}     ${D}..${NC}  ${W}${cpu_usage}%%${NC}$(printf '%*s' $((29)) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Memory${NC}        ${D}..${NC}  ${W}${mem}${NC}$(printf '%*s' $((29 - ${#mem})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Disk${NC}          ${D}..${NC}  ${W}${disk}${NC}$(printf '%*s' $((29 - ${#disk})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Network I/O${NC}   ${D}..${NC}  ${D}RX/TX: ${net}${NC}$(printf '%*s' $((18 - ${#net})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}  ${W}Load Average${NC}  ${D}..${NC}  ${W}${load}${NC}$(printf '%*s' $((29 - ${#load})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
    echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CB}  │${NC}  ${W}SERVICE STATUS${NC}                                          ${CB}│${NC}"
    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"

    for svc in xray nginx dropbear stunnel4 ws-openssh ws-dropbear ws-stunnel; do
        local dot=""
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            dot="${GB}●${NC}"
        else
            dot="${RB}●${NC}"
        fi
        echo -e "${CB}  │${NC}  ${W}  ${dot}  ${svc}${NC}$(printf '%*s' $((38 - ${#svc})) '' | tr ' ' ' ') ${CB}│${NC}"
    done

    if command -v wstunnel &>/dev/null; then
        local dot=""
        systemctl is-active --quiet proxy--ws && dot="${GB}●${NC}" || dot="${RB}●${NC}"
        echo -e "${CB}  │${NC}  ${W}  ${dot}  proxy--ws (wstunnel)${NC}$(printf '%*s' $((27)) '' | tr ' ' ' ') ${CB}│${NC}"
    fi

    if systemctl is-active --quiet haproxy 2>/dev/null; then
        echo -e "${CB}  │${NC}  ${W}  ${GB}●${NC}  haproxy (SNI router)$(printf '%*s' $((27)) '' | tr ' ' ' ') ${CB}│${NC}"
    fi

    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
    echo -e "${CB}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CB}  │${NC}  ${W}Xray Version${NC}  ${D}..${NC}  ${W}${xv}${NC}$(printf '%*s' $((26 - ${#xv})) '' | tr ' ' ' ')${CB}│${NC}"
    echo -e "${CB}  │${NC}                                                          ${CB}│${NC}"
    echo -e "${CB}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "    ${CB}Port Mapping${NC}"
    echo -e "    ${C}─────────────────────────────────────────────────────────${NC}"
    echo -e "    ${W}  80 / 443${NC}       ${D}->${NC} ${W}Xray (VMess/VLess/Trojan/SS) via Nginx${NC}"
    echo -e "    ${W}  2093${NC}           ${D}->${NC} ${W}SSH-WS (OpenSSH)${NC}"
    echo -e "    ${W}  2095${NC}           ${D}->${NC} ${W}SSH-WS (Dropbear)${NC}"
    echo -e "    ${W}  445${NC}            ${D}->${NC} ${W}SSH-SSL (Stunnel4 -> ws-stunnel)${NC}"
    echo -e "    ${W}  8880${NC}           ${D}->${NC} ${W}SSH-WS (wstunnel/Rust)${NC}"
    if systemctl is-active --quiet haproxy; then
        echo -e "    ${MB}  443 (SNI)${NC}      ${D}->${NC} ${W}HAProxy (Xray / SSH-SSL)${NC}"
    fi
    echo -e "    ${C}─────────────────────────────────────────────────────────${NC}"
    echo ""
    press_enter
}

sysinfo_dashboard