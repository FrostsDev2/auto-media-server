#!/usr/bin/env bash
# =============================================================================
#  Home Server Setup Script
#  Interactive installer for a Docker-based home media & automation server
# =============================================================================

set -euo pipefail

# ── Colors & helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CHECKMARK="${GREEN}✔${NC}"
CROSS="${RED}✘${NC}"
ARROW="${CYAN}➜${NC}"

log()     { echo -e "${ARROW} $*"; }
success() { echo -e "${CHECKMARK} $*"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${CROSS} ${RED}$*${NC}"; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE}  $*${NC}"; echo -e "${BOLD}${BLUE}══════════════════════════════════════${NC}\n"; }
section() { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# Ask yes/no — returns 0 for yes, 1 for no
ask() {
    local prompt="$1"
    local default="${2:-y}"
    local yn_hint
    if [[ "$default" == "y" ]]; then yn_hint="[Y/n]"; else yn_hint="[y/N]"; fi
    while true; do
        echo -ne "${BOLD}${prompt}${NC} ${DIM}${yn_hint}${NC} "
        read -r reply
        reply="${reply:-$default}"
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     echo "  Please answer y or n." ;;
        esac
    done
}

# Ask for a value with an optional default
ask_value() {
    local prompt="$1"
    local default="${2:-}"
    local hint=""
    [[ -n "$default" ]] && hint=" ${DIM}(default: $default)${NC}"
    echo -ne "${BOLD}${prompt}${NC}${hint}: "
    read -r val
    echo "${val:-$default}"
}

# Numbered menu — sets $MENU_CHOICE (1-based index)
menu() {
    local prompt="$1"; shift
    local options=("$@")
    echo -e "${BOLD}${prompt}${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}. ${options[$i]}"
    done
    while true; do
        echo -ne "${BOLD}Choice${NC} [1-${#options[@]}]: "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            MENU_CHOICE=$choice
            return
        fi
        echo "  Invalid choice. Enter a number between 1 and ${#options[@]}."
    done
}

# Multi-select menu — sets MULTI_CHOICES as array of selected indices (1-based)
multi_menu() {
    local prompt="$1"; shift
    local options=("$@")
    echo -e "${BOLD}${prompt}${NC} ${DIM}(comma-separated numbers, e.g. 1,3,4 or 'all')${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}. ${options[$i]}"
    done
    while true; do
        echo -ne "${BOLD}Choices${NC}: "
        read -r raw
        if [[ "${raw,,}" == "all" ]]; then
            MULTI_CHOICES=()
            for i in "${!options[@]}"; do MULTI_CHOICES+=($((i+1))); done
            return
        fi
        IFS=',' read -ra parts <<< "$raw"
        local valid=true
        MULTI_CHOICES=()
        for p in "${parts[@]}"; do
            p="${p// /}"
            if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= ${#options[@]} )); then
                MULTI_CHOICES+=("$p")
            else
                echo "  Invalid selection: $p"
                valid=false
                break
            fi
        done
        $valid && return
    done
}

# ── State variables ───────────────────────────────────────────────────────────
INSTALL_DIR=""
TZ=""
PUID=1000
PGID=1000
MEDIA_MOUNTS=()          # selected mount paths for media
DOWNLOAD_MOUNT=""        # selected mount path for downloads

# Service flags
USE_VPN=false
USE_QBITTORRENT=false
USE_PROWLARR=false
USE_SONARR=false
USE_RADARR=false
USE_LIDARR=false
USE_JELLYFIN=false
USE_JELLYSEERR=false
USE_WATCHTOWER=false
USE_DISPATCHARR=false
USE_PORTAINER=false
USE_HOMARR=false
USE_PIHOLE=false
USE_UPTIME_KUMA=false

# VPN config
VPN_PROVIDER=""
VPN_TYPE=""
WG_PRIVATE_KEY=""
WG_ADDRESSES=""
OPENVPN_USER=""
OPENVPN_PASSWORD=""

# Media paths (filled in during mount selection)
TV_PATH=""
MOVIES_PATH=""
MUSIC_PATH=""
DOWNLOADS_PATH=""
MEDIA_ROOT=""

# ─────────────────────────────────────────────────────────────────────────────
#  WELCOME
# ─────────────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
cat << 'BANNER'
  _   _                        ____
 | | | | ___  _ __ ___   ___ / ___|  ___ _ ____   _____ _ __
 | |_| |/ _ \| '_ ` _ \ / _ \\___ \ / _ \ '__\ \ / / _ \ '__|
 |  _  | (_) | | | | | |  __/ ___) |  __/ |   \ V /  __/ |
 |_| |_|\___/|_| |_| |_|\___||____/ \___|_|    \_/ \___|_|

  Interactive Home Server Installer
BANNER
echo -e "${NC}"
echo -e "${DIM}This script will install and configure your home server stack"
echo -e "using Docker Compose. Answer the questions to build your setup.${NC}\n"

# Must be root
if [[ $EUID -ne 0 ]]; then
    error "Please run as root: sudo bash homeserver-setup.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 1 — BASIC SYSTEM CONFIG
# ─────────────────────────────────────────────────────────────────────────────
header "Step 1 — Basic Configuration"

# Install directory
INSTALL_DIR=$(ask_value "Where should the server stack live?" "/opt/homeserver")
mkdir -p "$INSTALL_DIR"
success "Install directory: $INSTALL_DIR"

# Timezone
section "Timezone"
echo -e "Common timezones:"
echo -e "  ${DIM}America/New_York  America/Chicago  America/Denver  America/Los_Angeles"
echo -e "  Europe/London  Europe/Berlin  Asia/Tokyo  Australia/Sydney${NC}"
TZ=$(ask_value "Enter your timezone" "America/Chicago")
success "Timezone: $TZ"

# PUID/PGID
section "User IDs"
echo -e "${DIM}These are used by LinuxServer.io containers to run as your user."
echo -e "Run 'id \$USER' to find your UID/GID if unsure.${NC}"
PUID=$(ask_value "PUID (your user ID)" "1000")
PGID=$(ask_value "PGID (your group ID)" "1000")
success "Running containers as UID=$PUID GID=$PGID"

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 2 — DETECT EXTERNAL DRIVES
# ─────────────────────────────────────────────────────────────────────────────
header "Step 2 — Storage"

section "Detecting mounted drives and partitions..."

# Get all mounted block devices (excluding system paths)
AVAILABLE_MOUNTS=()
while IFS= read -r line; do
    mountpoint=$(echo "$line" | awk '{print $6}' | tr -d '()')
    device=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    fstype=$(echo "$line" | awk '{print $3}')
    # Exclude system mounts
    if [[ "$mountpoint" != "/" ]] && \
       [[ "$mountpoint" != "/boot"* ]] && \
       [[ "$mountpoint" != "/snap"* ]] && \
       [[ "$mountpoint" != "/sys"* ]] && \
       [[ "$mountpoint" != "/proc"* ]] && \
       [[ "$mountpoint" != "/dev"* ]] && \
       [[ "$mountpoint" != "/run"* ]] && \
       [[ "$fstype" != "tmpfs" ]] && \
       [[ "$fstype" != "devtmpfs" ]] && \
       [[ "$fstype" != "squashfs" ]] && \
       [[ -n "$mountpoint" ]]; then
        AVAILABLE_MOUNTS+=("$mountpoint  ${DIM}[$device · $size · $fstype]${NC}")
    fi
done < <(findmnt -rn -o TARGET,SOURCE,FSTYPE,SIZE,AVAIL,OPTIONS 2>/dev/null | tail -n +1)

# Also scan /mnt and /media for unmounted dirs
for base in /mnt /media; do
    if [[ -d "$base" ]]; then
        while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            already=false
            for m in "${AVAILABLE_MOUNTS[@]:-}"; do
                [[ "$m" == "$dir"* ]] && already=true && break
            done
            $already || AVAILABLE_MOUNTS+=("$dir  ${DIM}[not mounted — would need manual mount]${NC}")
        done < <(find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    fi
done

if [[ ${#AVAILABLE_MOUNTS[@]} -eq 0 ]]; then
    warn "No external drives detected. You can enter paths manually."
    MANUAL_PATHS=true
else
    echo -e "Found the following drives/partitions:\n"
    for i in "${!AVAILABLE_MOUNTS[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}. ${AVAILABLE_MOUNTS[$i]}"
    done
    echo ""
    MANUAL_PATHS=false
fi

# Helper to pick a mount or type manually
pick_path() {
    local prompt="$1"
    local varname="$2"
    local default="$3"

    if [[ "$MANUAL_PATHS" == "true" ]] || [[ ${#AVAILABLE_MOUNTS[@]} -eq 0 ]]; then
        local val
        val=$(ask_value "$prompt" "$default")
        eval "$varname='$val'"
        return
    fi

    echo -e "${BOLD}${prompt}${NC} ${DIM}(enter number from list, or type a custom path)${NC}"
    echo -ne "Choice: "
    read -r input
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#AVAILABLE_MOUNTS[@]} )); then
        # Extract just the path (before first space)
        local chosen
        chosen=$(echo "${AVAILABLE_MOUNTS[$((input-1))]}" | awk '{print $1}')
        eval "$varname='$chosen'"
    else
        eval "$varname='$input'"
    fi
}

section "Media storage paths"
echo -e "${DIM}You can use the same drive for everything, or different drives per media type.${NC}\n"

if ask "Do you want to store all media on a single drive/path?"; then
    pick_path "Select your main media drive" "MEDIA_ROOT" "/mnt/storage"
    TV_PATH="${MEDIA_ROOT}/TV Shows"
    MOVIES_PATH="${MEDIA_ROOT}/Movies"
    MUSIC_PATH="${MEDIA_ROOT}/Music"
    DOWNLOADS_PATH="${MEDIA_ROOT}/downloads"
    success "Media root: $MEDIA_ROOT"
else
    pick_path "TV Shows path" "TV_PATH" "/mnt/storage/TV Shows"
    pick_path "Movies path"   "MOVIES_PATH" "/mnt/storage/Movies"
    pick_path "Music path"    "MUSIC_PATH" "/mnt/storage/Music"
    pick_path "Downloads path" "DOWNLOADS_PATH" "/mnt/storage/downloads"
fi

# Create the directories
mkdir -p "$TV_PATH" "$MOVIES_PATH" "$MUSIC_PATH" "$DOWNLOADS_PATH"
success "Storage paths confirmed."

echo ""
echo -e "  ${DIM}TV Shows:  $TV_PATH"
echo -e "  Movies:    $MOVIES_PATH"
echo -e "  Music:     $MUSIC_PATH"
echo -e "  Downloads: $DOWNLOADS_PATH${NC}"

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 3 — VPN
# ─────────────────────────────────────────────────────────────────────────────
header "Step 3 — VPN (Gluetun)"

echo -e "${DIM}Gluetun routes qBittorrent and Prowlarr through a VPN."
echo -e "Required if you use a VPN for downloading.${NC}\n"

if ask "Do you want to use a VPN?"; then
    USE_VPN=true

    section "VPN Provider"
    PROVIDERS=("Mullvad" "NordVPN" "ExpressVPN" "Surfshark" "ProtonVPN" "Private Internet Access" "AirVPN" "Other (manual)")
    menu "Select your VPN provider:" "${PROVIDERS[@]}"
    VPN_PROVIDER_IDX=$MENU_CHOICE

    case $VPN_PROVIDER_IDX in
        1) VPN_PROVIDER="mullvad" ;;
        2) VPN_PROVIDER="nordvpn" ;;
        3) VPN_PROVIDER="expressvpn" ;;
        4) VPN_PROVIDER="surfshark" ;;
        5) VPN_PROVIDER="protonvpn" ;;
        6) VPN_PROVIDER="private internet access" ;;
        7) VPN_PROVIDER="airvpn" ;;
        8) VPN_PROVIDER=$(ask_value "Enter the provider name (as used by Gluetun)") ;;
    esac
    success "VPN provider: $VPN_PROVIDER"

    section "VPN Protocol"
    menu "Select VPN type:" "WireGuard (recommended — faster)" "OpenVPN"
    VPN_TYPE_IDX=$MENU_CHOICE

    if [[ $VPN_TYPE_IDX -eq 1 ]]; then
        VPN_TYPE="wireguard"
        echo ""
        echo -e "${DIM}You need your WireGuard private key and the VPN-assigned IP address."
        echo -e "For Mullvad: go to Account → WireGuard keys → Generate key.${NC}\n"
        WG_PRIVATE_KEY=$(ask_value "WireGuard private key")
        WG_ADDRESSES=$(ask_value "WireGuard address (e.g. 10.74.235.184/32)")
    else
        VPN_TYPE="openvpn"
        echo ""
        echo -e "${DIM}You need your OpenVPN username and password from your provider.${NC}\n"
        OPENVPN_USER=$(ask_value "OpenVPN username")
        echo -ne "${BOLD}OpenVPN password${NC}: "
        read -rs OPENVPN_PASSWORD
        echo ""
    fi
    success "VPN configured."
else
    warn "Skipping VPN — qBittorrent will use the host network directly."
fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 4 — SELECT SERVICES
# ─────────────────────────────────────────────────────────────────────────────
header "Step 4 — Choose Your Services"

section "Download stack"
if ask "Install qBittorrent? (torrent client)"; then USE_QBITTORRENT=true; fi
if ask "Install Prowlarr? (indexer manager)"; then USE_PROWLARR=true; fi

section "Media management (*arr suite)"
if ask "Install Sonarr? (TV show automation)"; then USE_SONARR=true; fi
if ask "Install Radarr? (movie automation)"; then USE_RADARR=true; fi
if ask "Install Lidarr? (music automation)"; then USE_LIDARR=true; fi

section "Media server"
if ask "Install Jellyfin? (media streaming server)"; then
    USE_JELLYFIN=true
    # Check for Intel GPU
    if [[ -d /dev/dri ]]; then
        success "Intel/AMD GPU detected at /dev/dri — hardware transcoding will be enabled."
        HW_TRANSCODE=true
    else
        warn "No GPU device found at /dev/dri — software transcoding only."
        HW_TRANSCODE=false
    fi
fi
if ask "Install Jellyseerr? (request management for Jellyfin)"; then USE_JELLYSEERR=true; fi
if ask "Install Dispatcharr? (live TV stream management)"; then USE_DISPATCHARR=true; fi

section "Utilities"
if ask "Install Watchtower? (auto-update containers daily)"; then USE_WATCHTOWER=true; fi
if ask "Install Portainer? (web GUI for managing Docker)"; then USE_PORTAINER=true; fi
if ask "Install Homarr? (home server dashboard)"; then USE_HOMARR=true; fi
if ask "Install Pi-hole? (network-wide ad blocking)"; then USE_PIHOLE=true; fi
if ask "Install Uptime Kuma? (service monitoring & alerts)"; then USE_UPTIME_KUMA=true; fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 5 — REVIEW & CONFIRM
# ─────────────────────────────────────────────────────────────────────────────
header "Step 5 — Review"

echo -e "${BOLD}Install directory:${NC} $INSTALL_DIR"
echo -e "${BOLD}Timezone:${NC}         $TZ"
echo -e "${BOLD}PUID/PGID:${NC}        $PUID / $PGID"
echo ""
echo -e "${BOLD}Storage:${NC}"
echo -e "  TV:        $TV_PATH"
echo -e "  Movies:    $MOVIES_PATH"
echo -e "  Music:     $MUSIC_PATH"
echo -e "  Downloads: $DOWNLOADS_PATH"
echo ""
echo -e "${BOLD}VPN:${NC} $([ "$USE_VPN" = true ] && echo "$VPN_PROVIDER ($VPN_TYPE)" || echo "disabled")"
echo ""
echo -e "${BOLD}Services to install:${NC}"

print_service() {
    local flag="$1" name="$2"
    if [[ "$flag" == "true" ]]; then
        echo -e "  ${CHECKMARK} $name"
    else
        echo -e "  ${DIM}✘ $name${NC}"
    fi
}

print_service "$USE_QBITTORRENT"  "qBittorrent"
print_service "$USE_PROWLARR"     "Prowlarr"
print_service "$USE_SONARR"       "Sonarr"
print_service "$USE_RADARR"       "Radarr"
print_service "$USE_LIDARR"       "Lidarr"
print_service "$USE_JELLYFIN"     "Jellyfin"
print_service "$USE_JELLYSEERR"   "Jellyseerr"
print_service "$USE_DISPATCHARR"  "Dispatcharr"
print_service "$USE_WATCHTOWER"   "Watchtower"
print_service "$USE_PORTAINER"    "Portainer"
print_service "$USE_HOMARR"       "Homarr"
print_service "$USE_PIHOLE"       "Pi-hole"
print_service "$USE_UPTIME_KUMA"  "Uptime Kuma"

echo ""
if ! ask "Everything look right? Proceed with installation?"; then
    echo "Aborted. Re-run the script to start over."
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 6 — INSTALL DOCKER
# ─────────────────────────────────────────────────────────────────────────────
header "Step 6 — Installing Docker"

if command -v docker &>/dev/null; then
    success "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # Add current user to docker group
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        success "Added $SUDO_USER to docker group."
    fi
    success "Docker installed: $(docker --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 7 — GENERATE docker-compose.yml
# ─────────────────────────────────────────────────────────────────────────────
header "Step 7 — Generating docker-compose.yml"

COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

# Start the file
cat > "$COMPOSE_FILE" << YAML_HEADER
# =============================================================================
#  Home Server — docker-compose.yml
#  Generated by homeserver-setup.sh on $(date)
# =============================================================================

services:
YAML_HEADER

# ── Gluetun (VPN) ────────────────────────────────────────────────────────────
if [[ "$USE_VPN" == "true" ]]; then
    VPN_PORTS=""
    [[ "$USE_QBITTORRENT" == "true" ]] && VPN_PORTS+='      - "8080:8080"   # qBittorrent
'
    [[ "$USE_PROWLARR" == "true" ]]    && VPN_PORTS+='      - "9696:9696"   # Prowlarr
'

    if [[ "$VPN_TYPE" == "wireguard" ]]; then
        VPN_EXTRA="      - WIREGUARD_PRIVATE_KEY=${WG_PRIVATE_KEY}
      - WIREGUARD_ADDRESSES=${WG_ADDRESSES}"
    else
        VPN_EXTRA="      - OPENVPN_USER=${OPENVPN_USER}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD}"
    fi

    cat >> "$COMPOSE_FILE" << YAML
  gluetun:
    image: qmcgaw/gluetun
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
${VPN_PORTS}    volumes:
      - ./gluetun:/gluetun
    environment:
      - VPN_SERVICE_PROVIDER=${VPN_PROVIDER}
      - VPN_TYPE=${VPN_TYPE}
${VPN_EXTRA}
    restart: unless-stopped

YAML
fi

# ── qBittorrent ───────────────────────────────────────────────────────────────
if [[ "$USE_QBITTORRENT" == "true" ]]; then
    if [[ "$USE_VPN" == "true" ]]; then
        QB_NETWORK='    network_mode: "service:gluetun"'
        QB_PORTS=""
    else
        QB_NETWORK=""
        QB_PORTS='    ports:
      - "8080:8080"'
    fi
    cat >> "$COMPOSE_FILE" << YAML
  qbittorrent:
    image: ghcr.io/linuxserver/qbittorrent
    container_name: qbittorrent
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - WEBUI_PORT=8080
    volumes:
      - ./qbittorrent:/config
      - ${DOWNLOADS_PATH}:/downloads
${QB_NETWORK}
${QB_PORTS}
    restart: unless-stopped

YAML
fi

# ── Prowlarr ──────────────────────────────────────────────────────────────────
if [[ "$USE_PROWLARR" == "true" ]]; then
    if [[ "$USE_VPN" == "true" ]]; then
        PR_NETWORK='    network_mode: "service:gluetun"'
        PR_PORTS=""
    else
        PR_NETWORK=""
        PR_PORTS='    ports:
      - "9696:9696"'
    fi
    cat >> "$COMPOSE_FILE" << YAML
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
${PR_NETWORK}
${PR_PORTS}
    volumes:
      - ./prowlarr:/config
    restart: unless-stopped

YAML
fi

# ── Sonarr ────────────────────────────────────────────────────────────────────
if [[ "$USE_SONARR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  sonarr:
    image: ghcr.io/linuxserver/sonarr
    container_name: sonarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ./sonarr:/config
      - ${TV_PATH}:/tv
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped

YAML
fi

# ── Radarr ────────────────────────────────────────────────────────────────────
if [[ "$USE_RADARR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  radarr:
    image: ghcr.io/linuxserver/radarr
    container_name: radarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ./radarr:/config
      - ${MOVIES_PATH}:/movies
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped

YAML
fi

# ── Lidarr ────────────────────────────────────────────────────────────────────
if [[ "$USE_LIDARR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  lidarr:
    image: ghcr.io/linuxserver/lidarr
    container_name: lidarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ./lidarr:/config
      - ${MUSIC_PATH}:/music
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - "8686:8686"
    restart: unless-stopped

YAML
fi

# ── Jellyfin ──────────────────────────────────────────────────────────────────
if [[ "$USE_JELLYFIN" == "true" ]]; then
    if [[ "${HW_TRANSCODE:-false}" == "true" ]]; then
        JF_DEVICES='    devices:
      - /dev/dri:/dev/dri   # Hardware transcoding (Intel QSV / AMD VAAPI)'
    else
        JF_DEVICES=""
    fi
    cat >> "$COMPOSE_FILE" << YAML
  jellyfin:
    image: ghcr.io/linuxserver/jellyfin
    container_name: jellyfin
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ./jellyfin:/config
      - ${TV_PATH}:/media/tv
      - ${MOVIES_PATH}:/media/movies
      - ${MUSIC_PATH}:/media/music
${JF_DEVICES}
    ports:
      - "8096:8096"
      - "8920:8920"   # HTTPS (optional)
      - "7359:7359/udp" # local discovery
    restart: unless-stopped

YAML
fi

# ── Jellyseerr ────────────────────────────────────────────────────────────────
if [[ "$USE_JELLYSEERR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - TZ=${TZ}
      - LOG_LEVEL=info
    ports:
      - "5055:5055"
    volumes:
      - ./jellyseerr:/app/config
    restart: unless-stopped

YAML
fi

# ── Dispatcharr ───────────────────────────────────────────────────────────────
if [[ "$USE_DISPATCHARR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  dispatcharr:
    image: ghcr.io/dispatcharr/dispatcharr:latest
    container_name: dispatcharr
    environment:
      - DISPATCHARR_ENV=aio
      - REDIS_HOST=localhost
      - CELERY_BROKER_URL=redis://localhost:6379/0
      - DISPATCHARR_LOG_LEVEL=info
    ports:
      - "9191:9191"
    volumes:
      - dispatcharr_data:/data
    restart: unless-stopped

YAML
fi

# ── Watchtower ────────────────────────────────────────────────────────────────
if [[ "$USE_WATCHTOWER" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 --cleanup
    restart: unless-stopped

YAML
fi

# ── Portainer ─────────────────────────────────────────────────────────────────
if [[ "$USE_PORTAINER" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    ports:
      - "9000:9000"
      - "9443:9443"
    restart: unless-stopped

YAML
fi

# ── Homarr ────────────────────────────────────────────────────────────────────
if [[ "$USE_HOMARR" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./homarr/configs:/app/data/configs
      - ./homarr/icons:/app/public/icons
      - ./homarr/data:/data
    ports:
      - "7575:7575"
    restart: unless-stopped

YAML
fi

# ── Pi-hole ───────────────────────────────────────────────────────────────────
if [[ "$USE_PIHOLE" == "true" ]]; then
    PIHOLE_PW=$(ask_value "Set a Pi-hole admin password" "changeme")
    cat >> "$COMPOSE_FILE" << YAML
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    environment:
      - TZ=${TZ}
      - WEBPASSWORD=${PIHOLE_PW}
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8053:80/tcp"   # Web UI on port 8053 to avoid conflict
    restart: unless-stopped

YAML
fi

# ── Uptime Kuma ───────────────────────────────────────────────────────────────
if [[ "$USE_UPTIME_KUMA" == "true" ]]; then
    cat >> "$COMPOSE_FILE" << YAML
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    volumes:
      - uptime_kuma_data:/app/data
    ports:
      - "3001:3001"
    restart: unless-stopped

YAML
fi

# ── Volumes section ───────────────────────────────────────────────────────────
VOLUMES_SECTION=""
[[ "$USE_DISPATCHARR" == "true" ]] && VOLUMES_SECTION+="  dispatcharr_data:\n"
[[ "$USE_PORTAINER"   == "true" ]] && VOLUMES_SECTION+="  portainer_data:\n"
[[ "$USE_UPTIME_KUMA" == "true" ]] && VOLUMES_SECTION+="  uptime_kuma_data:\n"

if [[ -n "$VOLUMES_SECTION" ]]; then
    echo -e "\nvolumes:" >> "$COMPOSE_FILE"
    echo -e "$VOLUMES_SECTION" >> "$COMPOSE_FILE"
fi

success "docker-compose.yml generated at $COMPOSE_FILE"

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 8 — WRITE .env FILE
# ─────────────────────────────────────────────────────────────────────────────
header "Step 8 — Writing .env"

cat > "$INSTALL_DIR/.env" << ENV
# Home Server Environment
# Generated: $(date)

PUID=${PUID}
PGID=${PGID}
TZ=${TZ}

TV_PATH=${TV_PATH}
MOVIES_PATH=${MOVIES_PATH}
MUSIC_PATH=${MUSIC_PATH}
DOWNLOADS_PATH=${DOWNLOADS_PATH}
ENV

success ".env written to $INSTALL_DIR/.env"

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 9 — PULL & START
# ─────────────────────────────────────────────────────────────────────────────
header "Step 9 — Starting Services"

cd "$INSTALL_DIR"

log "Pulling Docker images (this may take a few minutes)..."
docker compose pull

log "Starting all containers..."
docker compose up -d

success "All containers started!"

# ─────────────────────────────────────────────────────────────────────────────
#  DONE — Print service URLs
# ─────────────────────────────────────────────────────────────────────────────
header "Done! Your Services"

# Detect host IP for friendly URLs
HOST_IP=$(hostname -I | awk '{print $1}')

echo -e "${BOLD}Access your services at:${NC}\n"

[[ "$USE_QBITTORRENT"  == "true" ]] && echo -e "  ${CYAN}qBittorrent${NC}   http://${HOST_IP}:8080"
[[ "$USE_PROWLARR"     == "true" ]] && echo -e "  ${CYAN}Prowlarr${NC}      http://${HOST_IP}:9696"
[[ "$USE_SONARR"       == "true" ]] && echo -e "  ${CYAN}Sonarr${NC}        http://${HOST_IP}:8989"
[[ "$USE_RADARR"       == "true" ]] && echo -e "  ${CYAN}Radarr${NC}        http://${HOST_IP}:7878"
[[ "$USE_LIDARR"       == "true" ]] && echo -e "  ${CYAN}Lidarr${NC}        http://${HOST_IP}:8686"
[[ "$USE_JELLYFIN"     == "true" ]] && echo -e "  ${CYAN}Jellyfin${NC}      http://${HOST_IP}:8096"
[[ "$USE_JELLYSEERR"   == "true" ]] && echo -e "  ${CYAN}Jellyseerr${NC}    http://${HOST_IP}:5055"
[[ "$USE_DISPATCHARR"  == "true" ]] && echo -e "  ${CYAN}Dispatcharr${NC}   http://${HOST_IP}:9191"
[[ "$USE_PORTAINER"    == "true" ]] && echo -e "  ${CYAN}Portainer${NC}     http://${HOST_IP}:9000"
[[ "$USE_HOMARR"       == "true" ]] && echo -e "  ${CYAN}Homarr${NC}        http://${HOST_IP}:7575"
[[ "$USE_PIHOLE"       == "true" ]] && echo -e "  ${CYAN}Pi-hole${NC}       http://${HOST_IP}:8053/admin"
[[ "$USE_UPTIME_KUMA"  == "true" ]] && echo -e "  ${CYAN}Uptime Kuma${NC}   http://${HOST_IP}:3001"

echo ""
echo -e "${DIM}To manage your stack:${NC}"
echo -e "  cd ${INSTALL_DIR}"
echo -e "  docker compose ps          # see running containers"
echo -e "  docker compose logs -f     # follow all logs"
echo -e "  docker compose down        # stop everything"
echo -e "  docker compose pull && docker compose up -d  # update all"
echo ""
echo -e "${BOLD}${GREEN}Setup complete! Enjoy your home server.${NC}"
