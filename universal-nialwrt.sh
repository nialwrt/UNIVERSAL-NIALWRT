#!/bin/bash

# Color codes
BLUE='\033[1;34m' GREEN='\033[1;32m' RED='\033[1;31m' YELLOW='\033[1;33m'
CYAN='\033[1;36m' MAGENTA='\033[1;35m' NC='\033[0m' BOLD='\033[1m'

# Logging functions
log_info() { echo -e "${CYAN}>> ${NC}$1"; }
log_warning() { echo -e "${YELLOW}${BOLD}>> WARNING:${NC} ${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}${BOLD}>> ERROR:${NC} ${RED}${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}>> SUCCESS:${NC} ${GREEN}${BOLD}$1${NC}"; }
log_step() { echo -e "${BLUE}${BOLD}>> STEP:${NC} ${BLUE}${BOLD}$1${NC}"; }

# Prompt helper
prompt() {
    echo -ne "$1"
    read "$2"
}

# Check if git is installed
check_git() { command -v git &> /dev/null || { log_error "Git is required. Install it."; exit 1; }; }

# Main menu
main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  UNIVERSAL-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  https://github.com/nialwrt          ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${BLUE}${BOLD}Build Menu:${NC}"
    echo "1) OpenWrt"
    echo "2) OpenWrt-IPQ"
    echo "3) ImmortalWrt"
    while true; do
        prompt "Enter choice [1/2/3]: " choice
        case "$choice" in
            1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"; deps=(...); log_info "Selected: OpenWrt"; break ;;
            2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"; deps=(...); log_info "Selected: OpenWrt-IPQ"; break ;;
            3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"; deps=(...); log_info "Selected: ImmortalWrt"; break ;;
            *) log_error "Invalid selection."; ;;
        esac
    done
}

# Update feeds
update_feeds() {
    log_step "Updating package lists (feeds)..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing custom feeds... ${NC}"
    read
    log_step "Applying feed changes..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    log_success "Package lists (feeds) are ready."
}

# Select branch/tag
select_target() {
    log_step "Selecting target branch or tag..."
    log_info "Available branches:"; git branch -a | while read -r b; do log_info "  $b"; done
    log_info "Available tags:"; git tag | sort -V | while read -r t; do log_info "  $t"; done
    while true; do
        echo -ne "${BLUE}Enter branch/tag to checkout: ${NC}"
        read target_tag
        git checkout "$target_tag" && { log_success "Checked out to: $target_tag"; break; }
        log_error "Invalid selection."
    done
}

# Apply seed config
apply_seed_config() {
    [[ "$distro" == "openwrt-ipq" ]] || return
    log_step "Applying initial configuration..."
    cp nss-setup/config-nss.seed .config
    make defconfig
    log_success "Initial configuration applied."
}

# Run menuconfig
run_menuconfig() {
    log_step "Launching configuration menu..."
    make menuconfig && log_success "Configuration saved." || log_error "Configuration menu issues."
}

# Show build output location
show_output_location() {
    log_info "Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

# Start build
start_build() {
    log_step "Starting firmware build..."
    local MAKE_J=$(nproc)
    log_info "Using make -j${MAKE_J} based on available CPU cores."
    log_info "This may take a while."

    while true; do
        local start_time=$(date +%s)
        make -j"${MAKE_J}" && {
            local duration=$(( $(date +%s) - start_time ))
            local hours=$((duration / 3600)) minutes=$(((duration % 3600) / 60)) seconds=$((duration % 60))
            log_success "Build successful! Time: ${hours}h ${minutes}m ${seconds}s."
            show_output_location
            break
        }
        log_error "Build failed! Showing verbose output for debugging..."
        make -j1 V=s
        echo -ne "${RED}Fix errors, then press Enter to retry full process... ${NC}"
        read
        make distclean; update_feeds; run_menuconfig
    done
}

# Fresh build
fresh_build() {
    log_step "Starting a clean build for $distro..."
    if [ -d "$distro" ]; then
        echo -ne "${YELLOW}Directory '$distro' exists. Delete? [y/N]: ${NC}"
        read confirm_delete
        [[ "$confirm_delete" =~ ^[Yy]$ ]] && {
            log_info "Removing '$distro'..."
            rm -rf "$distro" || { log_error "Failed to remove."; return 1; }
        } || {
            log_info "Keeping '$distro'. Proceeding with rebuild."
            pushd "$distro" > /dev/null || return 1
            rebuild_menu
            popd > /dev/null
            return 0
        }
    fi
    log_step "Cloning repository..."
    git clone "$repo" "$distro" || { log_error "Failed to clone. Check network/URL."; return 1; }
    pushd "$distro" > /dev/null || return 1
    update_feeds || return 1
    select_target
    apply_seed_config
    run_menuconfig
    start_build
    popd > /dev/null
}

# Rebuild menu
rebuild_menu() {
    log_step "Rebuilding $distro..."
    pushd "$distro" > /dev/null || { log_error "Failed to enter '$distro'."; return 1; }
    echo -e "${BLUE}${BOLD}Rebuild Options:${NC}"
    echo "1) Updating Packages & Firmware"
    echo "2) Rebuilding with current settings"
    while true; do
        prompt "Select rebuild option [1/2]: " rebuild_choice
        case "$rebuild_choice" in
            1) log_info "Updating Packages & Firmware..."; make distclean; update_feeds; select_target; run_menuconfig; start_build; break ;;
            2) log_info "Rebuilding with current settings..."; make -j"$(nproc)" && { log_success "Rebuild completed."; show_output_location; break; } || { log_error "Rebuild failed. Initiating full recovery..."; update_feeds; make defconfig; run_menuconfig; start_build; break; } ;;
            *) log_error "Invalid selection."; ;;
        esac
    done
    popd > /dev/null
}

# Cleanup
[[ "$1" == "--clean" ]] && {
    log_step "Cleaning up..."
    echo -e "${BLUE}Manual cleanup may be needed.${NC}"
    [ -f "$script_file" ] && rm -f "$script_file" && log_info "Removed script."
    log_success "Cleanup done."
    exit 0
}

# Main logic
check_git
main_menu

if [ -d "$distro" ]; then
    echo -e "${BLUE}${BOLD}Directory '$distro' exists.${NC}"
    echo -e "${BLUE}${BOLD}Rebuild Menu:${NC}"
    echo "1) Fresh build"
    echo "2) Rebuild"
    while true; do
        prompt "Enter choice [1/2]: " build_type
        case "$build_type" in
            1) fresh_build; break ;;
            2) rebuild_menu; break ;;
            *) log_error "Invalid selection."; ;;
        esac
    done
else

    log_step "Installing required packages..."
    sudo apt update -y > /dev/null 2>&1
    sudo apt install -y "${deps[@]}" > /dev/null 2>&1
    log_success "Dependencies installed."
    fresh_build
fi

log_info "Script finished. Cleaning up..."
rm -f "$script_file"
log_success "Cleanup complete."
