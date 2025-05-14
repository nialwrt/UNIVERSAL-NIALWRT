#!/bin/bash

# Color codes
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'
BOLD='\033[1m'

# Get script file
script_file="$(readlink -f "$0")"

# Logging functions
log_info() { echo -e "${CYAN}>> ${NC}$1"; }
log_warning() { echo -e "${YELLOW}${BOLD}>> Warning:${NC} ${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}${BOLD}>> ERROR:${NC} ${RED}${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}>> SUCCESS:${NC} ${GREEN}${BOLD}$1${NC}"; }
log_step() { echo -e "${BLUE}${BOLD}>> STEP:${NC} ${BLUE}${BOLD}$1${NC}"; }

# Main menu
main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  UNIVERSAL-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  https://github.com/nialwrt          ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${BLUE}${BOLD}Select firmware distribution:${NC}"
    echo "1) OpenWrt: Popular Linux-based OS for embedded devices"
    echo "2) OpenWrt-IPQ: Optimized OpenWrt for IPQ platforms"
    echo "3) ImmortalWrt: OpenWrt fork with extra features/support"

    while true; do
        echo -ne "Enter choice [1/2/3]: "
        read choice
        case "$choice" in
            1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"; deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget); log_info "Selected: OpenWrt"; break ;;
            2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"; deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget); log_info "Selected: OpenWrt-IPQ"; break ;;
            3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"; deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd); log_info "Selected: ImmortalWrt"; break ;;
            *) log_error "Invalid selection. Please enter 1, 2, or 3."; ;;
        esac
    done
}

# Update feeds
update_feeds() {
    log_step "Updating package lists (feeds) from the internet..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || {
        log_error "Initial feeds update failed."
        return 1
    }

    echo -e "${BLUE}You can now add or edit custom feeds (e.g., feeds.conf.default).${NC}"
    echo -ne "Press Enter when done to re-run feeds update... "
    read

    log_step "Applying feed changes..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || {
        log_error "Failed to update feeds after manual edit."
        return 1
    }

    log_success "Package lists (feeds) are ready."
    return 0
}

# Select branch/tag
select_target() {
    log_step "Selecting target branch or tag..."

    log_info "Available branches:"
    git branch -a | while read -r branch; do log_info "  $branch"; done

    log_info "Available tags:"
    git tag | sort -V | while read -r tag; do log_info "  $tag"; done

    while true; do
        echo -ne "${BLUE}Enter a branch or tag to checkout:${NC} "
        read target_tag
        git checkout "$target_tag" && { log_success "Checked out to: $target_tag"; break; }
        log_error "Invalid selection: $target_tag. Try again."
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
    log_info "Firmware output will be located at:"
    echo -e "${YELLOW}$(pwd)/bin/targets/${NC}"
}

# Start build
start_build() {
    log_step "Starting firmware build..."
    log_info "This process may take a while. Please be patient."
    while true; do
        local start_time=$(date +%s)
        make -j"$(nproc)" && {
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))
            log_success "Build successful! Time taken: ${hours}h ${minutes}m ${seconds}s."
            show_output_location
            break
        }

        log_error "Build failed! Showing verbose output for debugging..."
        make -j1 V=s

        echo -ne "${RED}An error occurred during the build. Review the output above, fix any issues, and press Enter to retry the full process (update feeds, configure, build):${NC} "
        read

        update_feeds
        make defconfig
        run_menuconfig
    done
}

# Fresh build
fresh_build() {
    log_step "Starting a clean build for $distro..."

    [ -d "$distro" ] && {
        log_warning "Removing existing '$distro' directory..."
        rm -rf "$distro" || { log_error "Failed to remove directory."; return 1; }
    }

    log_step "Cloning repository from $repo..."
    git clone "$repo" "$distro" || { log_error "Failed to clone repository."; return 1; }
    log_success "Repository cloned."

    pushd "$distro" > /dev/null || return 1
    update_feeds || return 1
    select_target
    apply_seed_config
    run_menuconfig
    start_build
    popd > /dev/null
    return 0
}

# Rebuild menu
rebuild_menu() {
    log_step "Rebuilding $distro..."
    pushd "$distro" > /dev/null || { log_error "Failed to enter '$distro' folder."; return 1; }

    while true; do
        echo -e "${BLUE}${BOLD}Select rebuild option:${NC}"
        echo "1) Update Packages & Firmware"
        echo "2) Rebuild with Current Configuration"
        echo -ne "Enter choice [1/2]: "
        read rebuild_choice

        case "$rebuild_choice" in
            1)
                log_info "Cleaning build environment..."
                make distclean || { log_error "'make distclean' failed."; break; }

                log_info "Updating Packages & Firmware..."
                update_feeds || { log_error "Failed to update feeds."; break; }

                select_target
                run_menuconfig
                start_build
                break ;;
            2)
                log_info "Rebuilding with current settings..."
                make -j"$(nproc)" && {
                    log_success "Rebuild completed."
                    show_output_location
                    break
                }

                log_error "Rebuild failed. Initiating full cycle recovery..."
                update_feeds
                make defconfig
                run_menuconfig
                start_build
                break ;;
            *) log_error "Invalid selection. Enter 1 or 2." ;;
        esac
    done

    popd > /dev/null
}

# Cleanup
if [[ "$1" == "--clean" ]]; then
    log_step "Cleaning up..."
    echo -e "${BLUE}Manual directory cleanup may still be required.${NC}"
    [ -f "$script_file" ] && rm -f "$script_file" && log_info "Removed script: $script_file"
    log_success "Cleanup completed."
    exit 0
fi

# Main logic
main_menu

if [ -d "$distro" ]; then
    while true; do
        echo -e "${BLUE}Directory '${distro}' already exists.${NC}"
        echo "1) Fresh Build (delete & re-clone)"
        echo "2) Rebuild existing"
        echo -ne "Enter choice [1/2]: "
        read build_type
        case "$build_type" in
            1) fresh_build; break ;;
            2) rebuild_menu; break ;;
            *) log_error "Invalid selection. Enter 1 or 2." ;;
        esac
    done
else
    log_step "Installing required packages..."
    sudo apt update -y > /dev/null 2>&1
    sudo apt install --only-upgrade -y "${deps[@]}" > /dev/null 2>&1
    sudo apt install -y "${deps[@]}" > /dev/null 2>&1
    log_success "Dependencies installed."
    fresh_build
fi

log_info "Script finished. Cleaning up..."
rm -f "$script_file"
log_success "Cleanup complete."
