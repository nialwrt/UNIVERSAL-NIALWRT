#!/bin/bash

script_file="${BASH_SOURCE[0]}"

# Color codes
BLUE='\033[1;34m' GREEN='\033[1;32m' RED='\033[1;31m' YELLOW='\033[1;33m'
CYAN='\033[1;36m' MAGENTA='\033[1;35m' NC='\033[0m' BOLD='\033[1m'

# Logging functions
log_info() { echo -e "${CYAN}>> ${NC}$1"; }
log_warning() { echo -e "${YELLOW}${BOLD}>> WARNING:${NC} ${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}${BOLD}>> ERROR:${NC} ${RED}${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}>> SUCCESS:${NC} ${GREEN}${BOLD}$1${NC}"; }
log_step() { echo -e "${BLUE}${BOLD}>> STEP:${NC} ${BLUE}${BOLD}$1${NC}"; }

# Check prompt
prompt() {
    echo -ne "$1"
    read -r REPLY
    eval "$2=\"\$REPLY\""
}

# Check git
check_git() {
    command -v git &>/dev/null || {
        log_error "Git is required."
        exit 1
    }
}

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
        prompt "${YELLOW}Enter choice [1/2/3]: ${NC}" choice
        case "$choice" in
            1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"
               deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget)
               log_info "Selected: OpenWrt"; break ;;
            2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"
               deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget)
               log_info "Selected: OpenWrt-IPQ"; break ;;
            3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"
               deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)
               log_info "Selected: ImmortalWrt"; break ;;
            *) log_error "Invalid selection."; ;;
        esac
    done
}

update_feeds() {
    log_step "Updating package lists (feeds)..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing custom feeds... ${NC}"; read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    log_success "Package lists updated."
}

select_target() {
    log_step "Selecting target branch/tag..."
    echo -e "${YELLOW}Branches:${NC}"; git branch -a
    echo -e "${YELLOW}Tags:${NC}"; git tag | sort -V
    while true; do
        prompt "${BLUE}Enter branch/tag to checkout: ${NC}" target_tag
        git checkout "$target_tag" && { log_success "Checked out to: $target_tag"; break; }
        log_error "Invalid branch/tag."
    done
}

apply_seed_config() {
    [[ "$distro" == "openwrt-ipq" ]] || return
    log_step "Applying seed config..."
    if [[ -f "../nss-setup/config-nss.seed" ]]; then
        cp ../nss-setup/config-nss.seed .config
        make defconfig
        log_success "Seed config applied."
    else
        log_warning "Seed config not found. Skipping."
    fi
}

run_menuconfig() {
    log_step "Running menuconfig..."
    make menuconfig && log_success "Configuration saved." || log_error "Configuration failed."
}

show_output_location() {
    log_info "Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

start_build() {
    log_step "Building firmware..."
    local MAKE_J=$(nproc)
    log_info "Using make -j${MAKE_J}"

    while true; do
        local start_time=$(date +%s)
        make -j"${MAKE_J}" && {
            local duration=$(( $(date +%s) - start_time ))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))

            log_success "Build finished in ${hours}h ${minutes}m ${seconds}s."
            show_output_location
            generate_readme
            break
        }

        log_error "Build failed. Debugging with verbose output..."
        make -j1 V=s
        echo -ne "${RED}Fix errors, then press Enter to retry... ${NC}"
        read

        make distclean
        update_feeds || return 1
        select_target
        run_menuconfig

        local retry_start=$(date +%s)
        make -j"${MAKE_J}" && {
            local retry_duration=$(( $(date +%s) - retry_start ))
            local rh=$((retry_duration / 3600))
            local rm=$(((retry_duration % 3600) / 60))
            local rs=$((retry_duration % 60))

            log_success "Rebuild (after fallback) finished in ${rh}h ${rm}m ${rs}s."
            show_output_location
            generate_readme
        } || log_error "Build still failed after fallback."

        break
    done
}

fresh_build() {
    log_step "Clean build for $distro..."
    if [ -d "$distro" ]; then
        prompt "${YELLOW}Directory exists. Delete? [y/N]: ${NC}" confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && rm -rf "$distro" || {
            log_info "Using existing directory."
            pushd "$distro" > /dev/null
            rebuild_menu
            popd > /dev/null
            return
        }
    fi
    git clone "$repo" "$distro" || { log_error "Git clone failed."; return 1; }
    pushd "$distro" > /dev/null || return 1
    update_feeds || return 1
    select_target
    apply_seed_config
    run_menuconfig
    start_build
    popd > /dev/null
}

rebuild_menu() {
    pushd "$distro" > /dev/null || return 1
    echo -e "${BLUE}${BOLD}Rebuild Options:${NC}"
    echo "1) Fresh Rebuild (clean and reconfigure)"
    echo "2) Existing Rebuild (use current config)"

    while true; do
        prompt "${YELLOW}Select option [1/2]: ${NC}" opt
        case "$opt" in
            1)
                log_step "Performing fresh rebuild..."
                make distclean
                update_feeds || return 1
                select_target
                run_menuconfig
                start_build
                break
                ;;
            2)
                log_step "Rebuilding with existing settings..."
                make -j"$(nproc)" && {
                    log_success "Rebuild success."
                    show_output_location
                    break
                } || {
                    log_error "Rebuild failed. Fallback to fresh rebuild..."
                    make distclean
                    update_feeds || return 1
                    select_target
                    run_menuconfig
                    start_build
                    break
                }
                ;;
            *) log_error "Invalid selection."; ;;
        esac
    done

    popd > /dev/null
}

[[ "$1" == "--clean" ]] && {
    log_step "Cleaning up..."
    rm -f "$script_file" && log_info "Script removed."
    log_success "Cleanup complete."; exit 0
}

check_git
main_menu

if [ -d "$distro" ]; then
    echo -e "${BLUE}${BOLD}Directory '$distro' exists.${NC}"
    rebuild_menu
else
    log_step "Installing dependencies..."
    if sudo apt update -y > /dev/null 2>&1 && sudo apt install -y "${deps[@]}" > /dev/null 2>&1; then
        log_success "Dependencies installed."
    else
        log_error "Failed to install packages."
        exit 1
    fi
    fresh_build
fi

log_info "Script done."
rm -f "$script_file"
log_success "Self-cleaned successfully."
