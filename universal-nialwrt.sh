#!/bin/bash

# Define color codes (as before)
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# Get script name
script_file="$(readlink -f "$0")"

# Logging functions (as before)
log_info() { local msg="$1"; echo -e "${CYAN}>> ${NC}$msg"; }
log_warning() { local msg="$1"; echo -e "${YELLOW}${BOLD}>> Warning:${NC} ${YELLOW}$msg${NC}"; }
log_error() { local msg="$1"; echo -e "${RED}${BOLD}>> ERROR:${NC} ${RED}${BOLD}$msg${NC}"; }
log_success() { local msg="$1"; echo -e "${GREEN}${BOLD}>> SUCCESS:${NC} ${GREEN}${BOLD}$msg${NC}"; }
log_step() { local msg="$1"; echo -e "${BLUE}${BOLD}>> STEP:${NC} ${BLUE}${BOLD}$msg${NC}"; }

# Main menu function
main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  UNIVERSAL-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  https://github.com/nialwrt      ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                     ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${BLUE}${BOLD}Select firmware distribution:${NC}"
    echo "1) OpenWrt"
    echo "2) OpenWrt-IPQ"
    echo "3) ImmortalWrt"

    local choice
    while true; do
        read -p "Enter choice [1/2/3]: " choice
        case "$choice" in
            1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"; deps=("build-essential" "clang" "flex" "bison" "g++" "gawk" "gcc-multilib" "g++-multilib" "gettext" "git" "libncurses5-dev" "libssl-dev" "python3-setuptools" "rsync" "swig" "unzip" "zlib1g-dev" "file" "wget"); break ;;
            2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"; deps=("build-essential" "clang" "flex" "bison" "g++" "gawk" "gcc-multilib" "g++-multilib" "gettext" "git" "libncurses5-dev" "libssl-dev" "python3-setuptools" "rsync" "swig" "unzip" "zlib1g-dev" "file" "wget"); break ;;
            3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"; deps=("ack" "antlr3" "asciidoc" "autoconf" "automake" "autopoint" "binutils" "bison" "build-essential" "bzip2" "ccache" "clang" "cmake" "cpio" "curl" "device-tree-compiler" "ecj" "fastjar" "flex" "gawk" "gettext" "gcc-multilib" "g++-multilib" "git" "gnutls-dev" "gperf" "haveged" "help2man" "intltool" "lib32gcc-s1" "libc6-dev-i386" "libelf-dev" "libglib2.0-dev" "libgmp3-dev" "libltdl-dev" "libmpc-dev" "libmpfr-dev" "libncurses-dev" "libpython3-dev" "libreadline-dev" "libssl-dev" "libtool" "libyaml-dev" "libz-dev" "lld" "llvm" "lrzsz" "mkisofs" "msmtp" "nano" "ninja-build" "p7zip" "p7zip-full" "patch" "pkgconf" "python3" "python3-pip" "python3-ply" "python3-docutils" "python3-pyelftools" "qemu-utils" "re2c" "rsync" "scons" "squashfs-tools" "subversion" "swig" "texinfo" "uglifyjs" "upx-ucl" "unzip" "vim" "wget" "xmlto" "xxd" "zlib1g-dev" "zstd"); break ;;
            *) log_error "Invalid selection. Please enter 1, 2, or 3."; ;;
        esac
    done
    log_info "Selected distribution: $distro"
}

# Function to handle fresh build
fresh_build() {
    log_step "Starting fresh build for $distro..."

    # Remove existing directory (if it exists)
    if [ -d "$distro" ]; then
        log_warning "Removing existing '$distro' directory..."
        rm -rf "$distro"
        if [ "$?" -ne 0 ]; then
            log_error "Failed to remove existing directory. Exiting.";
            return 1 # Indicate failure
        fi
    fi

    # Clone the repository
    log_step "Cloning repository from $repo to $distro..."
    git clone "$repo" "$distro"
    if [ "$?" -ne 0 ]; then
        log_error "Failed to clone repository. Exiting.";
        return 1 # Indicate failure
    fi
    log_success "Repository cloned successfully."

    cd "$distro"

    # Setup feeds, select target, apply config, run menuconfig, and start build
    update_feeds
    select_target
    apply_seed_config
    run_menuconfig
    start_build

    cd ..
    return 0 # Indicate success
}

# Function to handle rebuild menu
rebuild_menu() {
    log_step "Rebuilding $distro..."
    cd "$distro"

    while true; do
        echo -e "${BLUE}${BOLD}Select rebuild option:${NC}"
        echo -e "1) Package & Firmware update"
        echo -e "2) Preset & Setting update"

        local rebuild_choice
        read -p "Enter choice [1/2]: " rebuild_choice

        case "$rebuild_choice" in
            1)  log_info "Updating Package & Firmware...";
                if update_feeds; then
                    git checkout;
                    rm -f .config;
                    make menuconfig;
                    make -j "$(nproc)";
                    break
                else
                    log_error "Failed to update feeds. Rebuild aborted.";
                fi
                ;;
            2)  log_info "Updating Preset & Settings...";
                make -j "$(nproc)";
                break ;;
            *)  log_error "Invalid selection. Please enter 1 or 2."; ;;
        esac
    done

    cd ..
}

# Function to update feeds and retry
update_feeds() {
    log_step "Setting up/updating feeds..."

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
        return 0 # Indicate success
    else
        log_error "Failed to update and install feeds (initial attempt).";
        return 1 # Indicate failure
    fi
}

# Function to select target branch/tag
select_target() {
    log_step "Selecting target branch or tag..."

    log_info "Available branches:"
    git branch -a | while read -r branch; do log_info "  $branch"; done

    log_info "Available tags:"
    git tag | sort -V | while read -r tag; do log_info "  $tag"; done

    while true; do
        local target_tag
        read -p "${BLUE}Enter a branch or tag to checkout: ${NC} " target_tag

        log_info "Attempting to checkout: $target_tag"
        git checkout "$target_tag"
        if [ "$?" -eq 0 ]; then
            log_success "Checked out to: $target_tag"
            break
        else
            log_error "Invalid selection: $target_tag. Try again."
        fi
    done
}

# Function to apply seed config (OpenWrt-IPQ)
apply_seed_config() {
    if [[ "$distro" == "openwrt-ipq" ]]; then
        log_step "Applying pre-seeded .config..."
        cp nss-setup/config-nss.seed .config
        log_info "Running 'make defconfig'..."
        make defconfig
        run_menuconfig
        log_success "Pre-seeded configuration applied."
    fi
}

# Function to run menuconfig
run_menuconfig() {
    log_step "Configuring build options (menuconfig)..."
    log_info "Opening menuconfig..."
    make menuconfig
    if [ "$?" -ne 0 ]; then
        log_error "menuconfig exited with errors. Build may be incomplete.";
    else
        log_success "menuconfig closed."
    fi
}

# Function to handle the build process with error recovery
start_build() {
    local build_successful=false
    log_step "Starting the main build process..."

    while true; do
        log_info "Running 'make -j$(nproc)'..."
        local start_time=$(date +%s)

        make -j"$(nproc)"
        if [ "$?" -eq 0 ]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            log_success "Build completed successfully. Duration: ${hours} hour(s) and ${minutes} minute(s)."
            build_successful=true
            break
        else
            log_error "Build failed. Retrying with verbose output ('make -j1 V=s')..."
            make -j1 V=s

            read -p "${RED}Please fix the error, then press Enter to continue...${NC}"

            # Feeds recovery loop
            update_feeds # Use the update_feeds function

            log_info "Running 'make defconfig' after build failure..."
            make defconfig
            run_menuconfig # Offer menuconfig again after error
        fi
    done
}

# Cleanup mode
if [[ "$1" == "--clean" ]]; then
    log_step "Cleaning up..."
    echo -e "${BLUE}${BOLD}Cleaning up...${NC}"
    echo -e "${BLUE}Please manually remove the distro folder if you want to clean it.${NC}"
    [ -f "$script_file" ] && log_info "Removing script '$script_file'..." && rm -f "$script_file"
    log_success "Cleanup process finished."
    exit 0
fi

# Main logic
main_menu # Get distro choice

# Check for existing distro folder
if [ -d "$distro" ]; then
    while true; do
        echo -e "${BLUE}Distro folder '${distro}' found.${NC}"
        echo "1) Fresh Build (delete existing)"
        echo "2) Rebuild"

        local build_type
        read -p "Enter choice [1/2]: " build_type

        case "$build_type" in
            1) fresh_build; break ;;
            2) rebuild_menu; break ;;
            *) log_error "Invalid selection. Please enter 1 or 2."; ;;
        esac
    done
else
    # Install dependencies (only for fresh build)
    log_step "Installing build dependencies..."
    log_info "Updating package lists..."
    sudo apt update -y > /dev/null 2>&1
    sudo apt install --only-upgrade -y "${deps[@]}" > /dev/null 2>&1
    sudo apt install -y "${deps[@]}" > /dev/null 2>&1
    log_success "Dependencies updated/installed."
    fresh_build
fi

# Final cleanup
cd ..
log_info "Removing this script '$script_file'..."
rm -f "$script_file"

log_success "Script execution finished."
