#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Get script name
script_file="$(basename "$0")"

# Define log file
log_file="build.log"

# Function to log messages
log_info() {
    local message="$1"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[INFO] [$timestamp] $message" >> "$log_file"
    echo "[INFO] [$timestamp] $message" # Tampilkan juga di terminal
}

log_error() {
    local message="$1"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[ERROR] [$timestamp] $message" >> "$log_file"
    echo -e "${RED}${BOLD}Error:${NC} ${RED}$message${NC}" # Tampilkan di terminal dengan warna merah
}

log_success() {
    local message="$1"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[SUCCESS] [$timestamp] $message" >> "$log_file"
    echo -e "${GREEN}${BOLD}Success:${NC} ${GREEN}$message${NC}" # Tampilkan di terminal dengan warna hijau
}

# Function to display main menu
main_menu() {
    clear
    echo -e "\e[34m--------------------------------------\e[0m"
    echo -e "\e[34m  UNIVERSAL-NIALWRT Firmware Build\e[0m"
    echo -e "\e[34m  https://github.com/nialwrt\e[0m"
    echo -e "\e[34m  Telegram: @NIALVPN\e[0m"
    echo -e "\e[34m--------------------------------------\e[0m"
    echo -e "${BLUE}Select firmware distribution:${NC}"
    echo "1) OpenWrt"
    echo "2) OpenWrt-IPQ"
    echo "3) ImmortalWrt"
    read -p "Enter choice [1/2/3]: " choice

    case "$choice" in
        1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"; deps=("build-essential" "clang" "flex" "bison" "g++" "gawk" "gcc-multilib" "g++-multilib" "gettext" "git" "libncurses5-dev" "libssl-dev" "python3-setuptools" "rsync" "swig" "unzip" "zlib1g-dev" "file" "wget");;
        2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"; deps=("build-essential" "clang" "flex" "bison" "g++" "gawk" "gcc-multilib" "g++-multilib" "gettext" "git" "libncurses5-dev" "libssl-dev" "python3-setuptools" "rsync" "swig" "unzip" "zlib1g-dev" "file" "wget");;
        3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"; deps=("ack" "antlr3" "asciidoc" "autoconf" "automake" "autopoint" "binutils" "bison" "build-essential" "bzip2" "ccache" "clang" "cmake" "cpio" "curl" "device-tree-compiler" "ecj" "fastjar" "flex" "gawk" "gettext" "gcc-multilib" "g++-multilib" "git" "gnutls-dev" "gperf" "haveged" "help2man" "intltool" "lib32gcc-s1" "libc6-dev-i386" "libelf-dev" "libglib2.0-dev" "libgmp3-dev" "libltdl-dev" "libmpc-dev" "libmpfr-dev" "libncurses-dev" "libpython3-dev" "libreadline-dev" "libssl-dev" "libtool" "libyaml-dev" "libz-dev" "lld" "llvm" "lrzsz" "mkisofs" "msmtp" "nano" "ninja-build" "p7zip" "p7zip-full" "patch" "pkgconf" "python3" "python3-pip" "python3-ply" "python3-docutils" "python3-pyelftools" "qemu-utils" "re2c" "rsync" "scons" "squashfs-tools" "subversion" "swig" "texinfo" "uglifyjs" "upx-ucl" "unzip" "vim" "wget" "xmlto" "xxd" "zlib1g-dev" "zstd");;
        *) log_error "Invalid selection: $choice. Exiting."; exit 1 ;;
    esac
    log_info "Selected distribution: $distro"
}

# Function to handle fresh build
fresh_build() {
    log_info "Starting fresh build for $distro..."
    if [ -d "$distro" ]; then
        log_info "Removing existing '$distro' directory..."
        rm -rf "$distro"
    fi
    log_info "Cloning repository from $repo to $distro..."
    if git clone "$repo" "$distro"; then
        log_success "Repository cloned successfully."
        cd "$distro"
        setup_feeds
        select_target
        apply_seed_config
        run_menuconfig
        start_build
        cd ..
    else
        log_error "Failed to clone repository."
    fi
}

# Function to handle rebuild menu
rebuild_menu() {
    log_info "Rebuilding $distro..."
    cd "$distro"
    while true; do
        echo -e "${BLUE}Select rebuild option:${NC}"
        echo -e "1) Quick Rebuild: Use existing config"
        echo -e "2) Update pkgs/fw: Get latest (may take a while)"
        read -p "Enter choice [1/2]: " rebuild_choice

        case "$rebuild_choice" in
            1) log_info "Using existing configuration for quick rebuild."; make defconfig; start_build; break ;;
            2) log_info "Updating feeds and rebuilding."; update_feeds; select_target; apply_seed_config; run_menuconfig; start_build; break ;;
            *) log_error "Invalid selection: $rebuild_choice. Try again." ;;
        esac
    done
    cd ..
}

# Function to setup feeds
setup_feeds() {
    log_info "Setting up feeds..."
    if ./scripts/feeds update -a && ./scripts/feeds install -a; then
        log_success "Feeds updated and installed."
        while true; do
            echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
            read -p "Press Enter to continue..." temp
            if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                log_success "Feeds updated and installed (retry)."
                break
            else
                log_error "Feeds update/install failed (retry). Please address the issue, then press Enter to retry..."
                read -r
            fi
        done
    else
        log_error "Failed to update and install feeds."
    fi
}

# Function to select target branch or tag
select_target() {
    log_info "Available branches:"
    git branch -a | while read -r branch; do log_info "  $branch"; done
    log_info "Available tags:"
    git tag | sort -V | while read -r tag; do log_info "  $tag"; done
    while true; do
        echo -ne "${BLUE}Enter a branch or tag to checkout: ${NC}"
        read TARGET_TAG
        log_info "Attempting to checkout: $TARGET_TAG"
        if git checkout "$TARGET_TAG"; then
            log_success "Checked out to: $TARGET_TAG"
            break
        else
            log_error "Invalid selection: $TARGET_TAG. Try again."
        fi
    done
}

# Function to apply seed config (for OpenWrt-IPQ)
apply_seed_config() {
    if [[ "$distro" == "openwrt-ipq" ]]; then
        log_info "Applying pre-seeded .config..."
        cp nss-setup/config-nss.seed .config
        log_info "Running 'make defconfig'..."
        make defconfig
        log_success "Pre-seeded configuration applied."
    fi
}

# Function to run menuconfig
run_menuconfig() {
    read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE}? [y/N]: ${NC})" mc
    if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
        log_info "Opening menuconfig..."
        make menuconfig
        log_success "menuconfig closed."
    else
        log_info "Skipping menuconfig."
    fi
}

# Function to update feeds
update_feeds() {
    log_info "Updating and installing feeds..."
    if ./scripts/feeds update -a && ./scripts/feeds install -a; then
        log_success "Feeds updated and installed."
        while true; do
            echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
            read -p "Press Enter to continue..." temp
            if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                log_success "Feeds updated and installed (retry)."
                break
            else
                log_error "Feeds update/install failed (retry). Please address the issue, then press Enter to retry..."
                read -r
            fi
        done
    else
        log_error "Failed to update and install feeds."
    fi
}

# Function to handle the build process with error recovery
start_build() {
    while true; do
        log_info "Starting build..."
        start_time=$(date +%s)

        if make -j"$(nproc)"; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            hours=$((duration / 3600))
            minutes=$(((duration % 3600) / 60))
            log_success "Build completed successfully. Duration: ${hours} hour(s) and ${minutes} minute(s)."
            break
        else
            log_error "Build failed. Retrying with verbose output..."
            make -j1 V=s

            read -p "${RED}Please fix the error, then press Enter to continue...${NC}"

            # Feeds recovery loop
            while true; do
                if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                    log_success "Feeds updated and installed (after build failure)."
                    break
                else
                    log_error "Feeds update/install failed (after build failure). Please fix and press Enter..."
                    read -r
                fi
            done

            log_info "Running 'make defconfig' after build failure..."
            make defconfig
            run_menuconfig # Offer menuconfig again after error
        fi
    done
}

# Cleanup mode
if [[ "$1" == "--clean" ]]; then
    log_info "Cleaning up..."
    echo -e "${BLUE}${BOLD}Cleaning up...${NC}"
    echo -e "${BLUE}Please manually remove the distro folder if you want to clean it.${NC}"
    [ -f "$script_file" ] && log_info "Removing script '$script_file'..." && rm -f "$script_file"
    log_success "Cleanup process finished."
    exit 0
fi

# Main logic to check for distro folder
main_menu # Get distro choice and set variables

if [ -d "$distro" ]; then
    while true; do
        echo -e "${BLUE}Distro folder '${distro}' found.${NC}"
        echo "1) Fresh Build (delete existing)"
        echo "2) Rebuild"
        read -p "Enter choice [1/2]: " build_type

        case "$build_type" in
            1) fresh_build; break ;;
            2) rebuild_menu; break ;;
            *) log_error "Invalid selection: $build_type. Try again." ;;
        esac
    done
else
    # Install build dependencies only for a fresh build
    log_info "Updating package lists..."
    sudo apt update -y > /dev/null 2>&1
    log_info "Attempting to upgrade existing dependencies..."
    sudo apt install --only-upgrade -y "${deps[@]}" > /dev/null 2>&1
    log_info "Installing missing dependencies..."
    sudo apt install -y "${deps[@]}" > /dev/null 2>&1
    log_success "Dependencies updated/installed."
    fresh_build
fi

# Final cleanup
cd ..
log_info "Removing this script '$script_file'..."
rm -f "$script_file"

sudo apt update && sudo apt install -y
log_info "Final apt update and upgrade completed."

log_success "Script execution finished."
