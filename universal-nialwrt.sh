#!/bin/bash

script_file="${BASH_SOURCE[0]}"

# Color codes
BLUE='\033[1;34m' GREEN='\033[1;32m' RED='\033[1;31m' YELLOW='\033[1;33m'
CYAN='\033[1;36m' MAGENTA='\033[1;35m' NC='\033[0m' BOLD='\033[1m'

distro=""
repo=""
deps=()
choice=""
target_tag=""
opt=""

prompt() {
    echo -ne "$1"
    read -r REPLY
    eval "$2=\"\$REPLY\""
}

check_git() {
    command -v git &>/dev/null || {
        echo -e "${RED}Error: Git is required.${NC}"
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
    echo -e "1) ${GREEN}ImmortalWrt${NC}"
    echo -e "2) ${GREEN}OpenWrt${NC}"
    while true; do
        prompt "${YELLOW}Enter choice [1/2]: ${NC}" choice
        case "$choice" in
            1) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"
               deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)
               echo -e "${GREEN}Selected: ImmortalWrt${NC}"; break ;;
            2) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"
               deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget)
               echo -e "${GREEN}Selected: OpenWrt${NC}"; break ;;
            *) echo -e "${RED}Invalid selection.${NC}"; ;;
        esac
    done
}

update_feeds() {
    echo -e "${CYAN}Updating package lists (feeds)...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing custom feeds... ${NC}"; read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${GREEN}Package lists updated.${NC}"
}

select_target() {
    echo -e "${CYAN}Selecting target branch/tag...${NC}"
    echo -e "${YELLOW}Branches:${NC}"; git branch -a
    echo -e "${YELLOW}Tags:${NC}"; git tag | sort -V
    while true; do
        prompt "${BLUE}Enter branch/tag to checkout: ${NC}" target_tag
        git checkout "$target_tag" && { echo -e "${GREEN}Checked out to: $target_tag${NC}"; break; }
        echo -e "${RED}Invalid branch/tag.${NC}"
    done
}

run_menuconfig() {
    echo -e "${CYAN}Running menuconfig...${NC}"
    make menuconfig && echo -e "${GREEN}Configuration saved.${NC}" || echo -e "${RED}Configuration failed.${NC}"
}

show_output_location() {
    echo -e "${CYAN}Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

start_build() {
    echo -e "${CYAN}Building firmware...${NC}"
    local MAKE_J=$(nproc)
    echo -e "${YELLOW}Using make -j${MAKE_J}${NC}"

    while true; do
        local start_time=$(date +%s)
        make -j"${MAKE_J}" && {
            local duration=$(( $(date +%s) - start_time ))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))

            echo -e "${GREEN}Build finished in ${hours}h ${minutes}m ${seconds}s.${NC}"
            show_output_location
            break
        }

        echo -e "${RED}Build failed. Debugging with verbose output...${NC}"
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

            echo -e "${GREEN}Rebuild (after fallback) finished in ${rh}h ${rm}m ${rs}s.${NC}"
            show_output_location
        } || echo -e "${RED}Build still failed after fallback.${NC}"

        break
    done
}

build_menu() {
    echo -e "${CYAN}Starting first-time build...${NC}"
    git clone "$repo" "$distro" || { echo -e "${RED}Git clone failed.${NC}"; exit 1; }
    pushd "$distro" > /dev/null || exit 1
    update_feeds || exit 1
    select_target
    run_menuconfig
    start_build
    popd > /dev/null
}

rebuild_menu() {
    pushd "$distro" > /dev/null || exit 1
    echo -e "${BLUE}${BOLD}Rebuild Options:${NC}"
    echo -e "1) ${YELLOW}Fresh Rebuild (clean and reconfigure)${NC}"
    echo -e "2) ${YELLOW}Configure and Rebuild (new .config)${NC}"
    echo -e "3) ${YELLOW}Existing Rebuild (use current config)${NC}"

    while true; do
        prompt "${YELLOW}Select option [1/2/3]: ${NC}" opt
        case "$opt" in
            1)
                echo -e "${CYAN}Performing fresh rebuild...${NC}"
                make distclean
                update_feeds || return 1
                select_target
                run_menuconfig
                start_build
                break
                ;;
            2)
                echo -e "${CYAN}Configuring and rebuilding (new .config)...${NC}"
                rm -f .config
                make menuconfig
                start_build
                break
                ;;
            3)
                echo -e "${CYAN}Rebuilding with existing settings...${NC}"
                start_build || {
                    echo -e "${RED}Rebuild failed. Consider a fresh rebuild.${NC}"
                }
                break
                ;;
            *) echo -e "${RED}Invalid selection.${NC}"; ;;
        esac
    done

    popd > /dev/null
}

cleanup() {
    rm -f "$script_file"
}

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    cleanup
    exit 0

check_git
main_menu

if [ -d "$distro" ]; then
    echo -e "${BLUE}Directory '$distro' exists.${NC}"
    rebuild_menu
else
    echo -e "${CYAN}Installing dependencies...${NC}"
    if sudo apt update -y > /dev/null 2>&1 && sudo apt install -y "${deps[@]}" > /dev/null 2>&1; then
        echo -e "${GREEN}Dependencies installed.${NC}"
    else
        echo -e "${RED}Failed to install packages.${NC}"
        exit 1
    fi
    build_menu
fi

cleanup
