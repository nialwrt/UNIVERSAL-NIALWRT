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
        echo -ne "${BOLD_BLUE}CHOOSE OPTION: ${RESET}"
        read -r opt
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

    echo -e "${BOLD_YELLOW}UPDATING SYSTEM PACKAGES...${RESET}"
    $SUDO apt update -y && $SUDO apt full-upgrade -y || {
        echo -e "${BOLD_RED}ERROR: SYSTEM UPDATE FAILED.${RESET}"
        exit 1
    }

    echo -e "${BOLD_YELLOW}INSTALLING DEPENDENCIES FOR ${distro^^}...${RESET}"
    $SUDO apt install -y "${deps[@]}" || {
        echo -e "${BOLD_RED}ERROR: FAILED TO INSTALL DEPENDENCIES. PLEASE CHECK YOUR SYSTEM AND TRY AGAIN.${RESET}"
        exit 1
    }
    echo -e "${BOLD_GREEN}DEPENDENCIES INSTALLED SUCCESSFULLY.${RESET}"
}

rebuild_menu() {
    clear
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
        echo -ne "${BOLD_BLUE}CHOOSE OPTION: ${RESET}"
        read -r opt
        case "$opt" in
            1)
                echo -e "${BOLD_YELLOW}REMOVING EXISTING BUILD DIRECTORY: ${distro}${RESET}"
                rm -rf "$distro"
                echo -e "${BOLD_YELLOW}CLONING FRESH FROM REPOSITORY: $repo${RESET}"
                git clone --depth=1 "$repo" "$distro" || {
                    echo -e "${BOLD_RED}ERROR: GIT CLONE FAILED.${RESET}"
                    exit 1
                }
                cd "$distro" || exit 1
                update_feeds || exit 1
                select_target
                run_menuconfig
                start_build
                break
                ;;
            2)
                echo -e "${BOLD_YELLOW}PERFORMING FAST REBUILD (MAKE CLEAN)...${RESET}"
                cd "$distro" || exit 1
                make clean
                select_target
                make defconfig
                start_build
                break
                ;;
            3)
                echo -e "${BOLD_YELLOW}STARTING BUILD WITH EXISTING CONFIGURATION...${RESET}"
                cd "$distro" || exit 1
                start_build
                break
                ;;
            *)
                echo -e "${BOLD_RED}INVALID CHOICE. PLEASE ENTER 1, 2, OR 3.${RESET}"
                ;;
        esac
    done
}

update_feeds() {
    echo -e "${BOLD_YELLOW}UPDATING FEEDS...${RESET}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || {
        echo -e "${BOLD_RED}ERROR: FEEDS UPDATE FAILED.${RESET}"
        return 1
    }
    echo -ne "${BOLD_BLUE}EDIT FEEDS IF NEEDED, THEN PRESS ENTER TO CONTINUE: ${RESET}"
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || {
        echo -e "${BOLD_RED}ERROR: FEEDS INSTALL FAILED AFTER EDIT.${RESET}"
        return 1
    }
    echo -e "${BOLD_GREEN}FEEDS UPDATED SUCCESSFULLY.${RESET}"
}

select_target() {
    echo -e "${BOLD_BLUE}AVAILABLE BRANCHES:${RESET}"
    git branch -a

    echo -e "${BOLD_BLUE}AVAILABLE TAGS:${RESET}"
    git tag | sort -V

    while true; do
        echo -ne "${BOLD_BLUE}ENTER BRANCH OR TAG TO CHECKOUT: ${RESET}"
        read -r target_tag
        if git checkout "$target_tag" &>/dev/null; then
            echo -e "${BOLD_GREEN}CHECKED OUT TO ${target_tag}${RESET}"
            break
        else
            echo -e "${BOLD_RED}INVALID BRANCH OR TAG: ${target_tag}${RESET}"
        fi
    done
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
    get_version
    while true; do
        echo -e "${BOLD_YELLOW}STARTING BUILD WITH $(nproc) CORES...${RESET}"
        local start=$(date +%s)

        if make -j"$(nproc)"; then
            echo -e "${BOLD_YELLOW}BUILD VERSION: ${version_branch}${version_tag}${RESET}"
            echo -e "${BOLD_BLUE}OUTPUT DIRECTORY: $(pwd)/bin/targets/${RESET}"
            local dur=$(( $(date +%s) - start ))
            printf "${BOLD_GREEN}BUILD COMPLETED IN %02dh %02dm %02ds${RESET}\n" \
                $((dur / 3600)) $(((dur % 3600) / 60)) $((dur % 60))
            rm -f -- "$script_path"
            break
        else
            echo -e "${BOLD_RED}BUILD FAILED. RETRYING WITH VERBOSE OUTPUT...${RESET}"
            make -j1 V=s
            echo -ne "${BOLD_RED}PLEASE FIX ERRORS AND PRESS ENTER TO RETRY: ${RESET}"
            read -r
            make distclean
            update_feeds || return 1
            select_target
            run_menuconfig
        fi
    done
}

build_menu() {
    echo -e "${BOLD_YELLOW}CLONING REPOSITORY: $repo ...${RESET}"
    git clone "$repo" "$distro" || {
        echo -e "${BOLD_RED}ERROR: GIT CLONE FAILED.${RESET}"
        exit 1
    }
    cd "$distro" || exit 1
    update_feeds || exit 1
    select_target
    run_menuconfig
    start_build
}

main_menu
if [ -d "$distro" ]; then
    rebuild_menu
else
    build_menu
fi
