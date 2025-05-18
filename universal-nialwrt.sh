#!/bin/bash

script_path="$(realpath "$0")"

RESET='\033[0m'
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'

BOLD_RED="${BOLD}${RED}"
BOLD_GREEN="${BOLD}${GREEN}"
BOLD_YELLOW="${BOLD}${YELLOW}"
BOLD_BLUE="${BOLD}${BLUE}"
BOLD_MAGENTA="${BOLD}${MAGENTA}"

build_menu() {
    echo -e "${BOLD_BLUE}CLONING REPO: $repo...${RESET}"
    git clone "$repo" "$distro" || {
        echo -e "${BOLD_RED}GIT CLONE FAILED.${RESET}"
        exit 1
    }
    cd "$distro" || exit 1
    select_target
    update_feeds || exit 1
    run_menuconfig
    start_build
}

main_menu() {
    clear
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_MAGENTA}  UNIVERSAL-NIALWRT FIRMWARE BUILD     ${RESET}"
    echo -e "${BOLD_MAGENTA}  https://github.com/nialwrt           ${RESET}"
    echo -e "${BOLD_MAGENTA}  TELEGRAM: @NIALVPN                   ${RESET}"
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_BLUE}BUILD MENU:${RESET}"
    echo -e "1) ImmortalWrt"
    echo -e "2) OpenWrt"

    while true; do
        prompt "${BOLD_BLUE}CHOOSE OPTION: ${RESET}" opt
        case "$opt" in
            1)
                distro="immortalwrt"
                repo="https://github.com/immortalwrt/immortalwrt.git"
                deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)
                break
                ;;
            2)
                distro="openwrt"
                repo="https://github.com/openwrt/openwrt.git"
                deps=(build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget)
                break
                ;;
            *)
                echo -e "${BOLD_RED}ERROR: INVALID SELECTION.${RESET}"
                ;;
        esac
    done

    if ! command -v sudo &>/dev/null; then
        SUDO=""
    else
        SUDO="sudo"
    fi

    echo -e "${BOLD_YELLOW}INSTALLING DEPENDENCIES FOR $distro...${RESET}"
    $SUDO apt update -y && $SUDO apt full-upgrade -y
    $SUDO apt install -y "${deps[@]}" || {
        echo -e "${BOLD_RED}FAILED TO INSTALL DEPENDENCIES. PLEASE CHECK YOUR SYSTEM AND TRY AGAIN.${RESET}"
        exit 1
    }
}

rebuild_menu() {
    clear
    cd "$distro" || exit 1
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_MAGENTA}  UNIVERSAL-NIALWRT FIRMWARE BUILD     ${RESET}"
    echo -e "${BOLD_MAGENTA}  https://github.com/nialwrt           ${RESET}"
    echo -e "${BOLD_MAGENTA}  TELEGRAM: @NIALVPN                   ${RESET}"
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_BLUE}REBUILD MENU:${RESET}"
    echo -e "1) FIRMWARE & PACKAGE UPDATE (FULL REBUILD)"
    echo -e "2) FIRMWARE UPDATE (FAST REBUILD)"
    echo -e "3) EXISTING UPDATE (NO CHANGES)"

    while true; do
        prompt "${BOLD_BLUE}CHOOSE OPTION: ${RESET}" opt
        case "$opt" in
            1)
                make distclean
                select_target
                update_feeds || exit 1
                run_menuconfig
                start_build
                break
                ;;
            2)
                make clean
                rm -f .config
                select_target
                make defconfig
                run_menuconfig
                start_build
                break
                ;;
            3)
                make clean
                start_build
                break
                ;;
            *)
                echo -e "${BOLD_RED}INVALID CHOICE. PLEASE ENTER 1, 2, OR 3.${RESET}"
                ;;
        esac
    done
}

select_target() {
    git fetch --all --tags
    echo -e "${BOLD_BLUE}BRANCHES:${RESET}"
    git branch -a
    echo -e "${BOLD_BLUE}TAGS:${RESET}"
    git tag | sort -V

    while true; do
        prompt "${BOLD_BLUE}ENTER BRANCH OR TAG: ${RESET}" target_tag
        git checkout "$target_tag" &>/dev/null && {
            echo -e "${BOLD_GREEN}CHECKED OUT TO $target_tag${RESET}"
            break
        } || echo -e "${BOLD_RED}INVALID BRANCH/TAG: $target_tag${RESET}"
    done
}

update_feeds() {
    echo -e "${BOLD_YELLOW}UPDATING FEEDS...${RESET}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BOLD_BLUE}EDIT FEEDS IF NEEDED, THEN PRESS ENTER: ${RESET}"
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${BOLD_GREEN}FEEDS UPDATED.${RESET}"
}

run_menuconfig() {
    echo -e "${BOLD_YELLOW}RUNNING MENUCONFIG...${RESET}"
    make menuconfig
    echo -e "${BOLD_GREEN}CONFIGURATION SAVED.${RESET}"
}

get_version() {
    version_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
    if [ -n "$version_tag" ]; then
        version_branch=""
    else
        version_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi
}

start_build() {
    while true; do
        echo -e "${BOLD_YELLOW}DOWNLOADING SOURCES...${RESET}"
        make download -j"$(nproc)"

        echo -e "${BOLD_YELLOW}BUILDING WITH $(nproc) CORES...${RESET}"
        local start=$(date +%s)

        if make -j"$(nproc)"; then
            local dur=$(( $(date +%s) - start ))
            printf "${BOLD_GREEN}BUILD COMPLETED IN %02dh %02dm %02ds${RESET}\n" \
                $((dur / 3600)) $(((dur % 3600) / 60)) $((dur % 60))
            echo -e "${BOLD_BLUE}OUTPUT: $(pwd)/bin/targets/${RESET}"
            get_version
            echo -e "${BOLD_YELLOW}VERSION: ${version_branch}${version_tag}${RESET}"
            break
        else
            echo -e "${BOLD_RED}BUILD FAILED: DEBUGGING WITH VERBOSE OUTPUT${RESET}"
            make -j1 V=s
            echo -ne "${BOLD_RED}PLEASE FIX ERROR AND PRESS ENTER TO RETRY${RESET}"
            read -r
            make distclean
            update_feeds || return 1
            select_target
            run_menuconfig
        fi
    done
}

cleanup() {
    echo -e "${BOLD_YELLOW}CLEANING UP...${RESET}"
    rm -f -- "$script_path"
}

check_git
main_menu
if [ -d "$distro" ]; then
    rebuild_menu
else
    build_menu
fi
