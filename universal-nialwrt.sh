#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Get script name
script_file="$(basename "$0")"

# Function to display main menu
main_menu() {
    clear
    echo -e "\e[${BLUE}34m--------------------------------------\e[${NC}0m"
    echo -e "\e[${BLUE}34m  ${BOLD}UNIVERSAL-NIALWRT Firmware Build\e[${NC}0m"
    echo -e "\e[${BLUE}34m  ${BOLD}https://github.com/nialwrt\e[${NC}0m"
    echo -e "\e[${BLUE}34m  ${BOLD}Telegram: @NIALVPN\e[${NC}0m"
    echo -e "\e[${BLUE}34m--------------------------------------\e[${NC}0m"
    echo -e "${BLUE}${BOLD}Select firmware distribution:${NC}"
    echo "${BOLD}1) ${GREEN}OpenWrt${NC}"
    echo "${BOLD}2) ${GREEN}OpenWrt-IPQ${NC}"
    echo "${BOLD}3) ${GREEN}ImmortalWrt${NC}"
    read -p "${BOLD}Enter choice [1/2/3]: ${NC}" choice

    case "$choice" in
        1) distro="openwrt"; repo="https://github.com/openwrt/openwrt.git"; deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget";;
        2) distro="openwrt-ipq"; repo="https://github.com/qosmio/openwrt-ipq.git"; deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget";;
        3) distro="immortalwrt"; repo="https://github.com/immortalwrt/immortalwrt.git"; deps="ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd";;
        *) echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Invalid selection. Exiting.${NC}"; exit 1 ;;
    esac
}

# Function to handle fresh build
fresh_build() {
    echo -e "${BLUE}${BOLD}Starting fresh build for ${distro}...${NC}"
    [ -d "$distro" ] && echo -e "${BLUE}${BOLD}Removing existing '${distro}' directory...${NC}" && rm -rf "$distro"
    echo -e "${BLUE}${BOLD}Cloning repository...${NC}"
    git clone "$repo" "$distro"
    cd "$distro"
    setup_feeds
    select_target
    apply_seed_config
    echo -e "${BLUE}${BOLD}Opening ${BOLD}menuconfig${NC}${BLUE}...${NC}"
    make menuconfig
    start_build
}

# Function to handle rebuild menu
rebuild_menu() {
    echo -e "${BLUE}${BOLD}Rebuilding ${distro}...${NC}"
    cd "$distro"
    while true; do
        echo -e "${BLUE}${BOLD}Select rebuild option:${NC}"
        echo -e "${BOLD}1) ${GREEN}Quick Rebuild${NC}${BOLD}: Use existing config${NC}"
        echo -e "${BOLD}2) ${GREEN}Update pkgs/fw${NC}${BOLD}: Get latest (may take a while)${NC}"
        read -p "${BOLD}Enter choice [1/2]: ${NC}" rebuild_choice

        case "$rebuild_choice" in
            1) echo -e "${BLUE}${BOLD}Using existing configuration...${NC}"; make defconfig; start_build ;;
            2) update_feeds; select_target; apply_seed_config; run_menuconfig; start_build ;;
            *) echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Invalid selection. Try again.${NC}" ;;
        esac
        [[ "$rebuild_choice" == "1" || "$rebuild_choice" == "2" ]] && break
    done
}

# Function to setup feeds
setup_feeds() {
    echo -e "${BLUE}${BOLD}Setting up feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a
    while true; do
        echo -e "${BLUE}${BOLD}You may now add custom feeds manually if needed.${NC}"
        read -p "${BOLD}Press Enter to continue...${NC}" temp
        ./scripts/feeds update -a && ./scripts/feeds install -a && break
        echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
        read -r
    done
}

# Function to select target branch or tag
select_target() {
    echo -e "${BLUE}${BOLD}Available branches:${NC}"
    git branch -a
    echo -e "${BLUE}${BOLD}Available tags:${NC}"
    git tag | sort -V
    while true; do
        echo -ne "${BLUE}${BOLD}Enter a branch or tag to checkout: ${NC}"
        read TARGET_TAG
        if git checkout "$TARGET_TAG"; then
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Invalid selection. Try again.${NC}"
        fi
    done
}

# Function to apply seed config (for OpenWrt-IPQ)
apply_seed_config() {
    if [[ "$distro" == "openwrt-ipq" ]]; then
        echo -e "${BLUE}${BOLD}Applying pre-seeded .config...${NC}"
        cp nss-setup/config-nss.seed .config
        echo -e "${BLUE}${BOLD}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig
    fi
}

# Function to run menuconfig (with prompt)
run_menuconfig() {
    read -p "$(echo -e ${BLUE}${BOLD}Do you want to open ${BOLD}menuconfig${NC}${BLUE}? [${GREEN}y${NC}/${RED}N${NC}]: ${NC})" mc
    if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
        echo -e "${BLUE}${BOLD}Opening ${BOLD}menuconfig${NC}${BLUE}...${NC}"
        make menuconfig
    fi
}

# Function to update feeds
update_feeds() {
    echo -e "${BLUE}${BOLD}Updating and installing feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a
    while true; do
        echo -e "${BLUE}${BOLD}You may now add custom feeds manually if needed.${NC}"
        read -p "${BOLD}Press Enter to continue...${NC}" temp
        ./scripts/feeds update -a && ./scripts/feeds install -a && break
        echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
        read -r
    done
}

# Function to handle the build process with error recovery
start_build() {
    while true; do
        echo -e "${BLUE}${BOLD}Starting build...${NC}"
        start_time=$(date +%s)

        if make -j"$(nproc)"; then
            echo -e "${GREEN}${BOLD}Build completed successfully.${NC}"
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            hours=$((duration / 3600))
            minutes=$(((duration % 3600) / 60))
            echo -e "${BLUE}${BOLD}Build duration: ${BOLD}${hours}${NC}${BLUE} hour(s) and ${BOLD}${minutes}${NC}${BLUE} minute(s).${NC}"
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Build failed. Retrying with verbose output...${NC}"
            make -j1 V=s

            read -p "${RED}${BOLD}Please fix the error, then press Enter to continue...${NC}"

            # Feeds recovery loop
            while true; do
                ./scripts/feeds update -a && ./scripts/feeds install -a && break
                echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Feeds update/install failed. Please fix and press Enter...${NC}"
                read -r
            done

            echo -e "${BLUE}${BOLD}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
            make defconfig
            # run_menuconfig # Jangan tawarkan menuconfig lagi setelah error di fresh build
        fi
    done
}

# Cleanup mode
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}${BOLD}Cleaning up...${NC}"
    echo -e "${BLUE}${BOLD}Please manually remove the distro folder if you want to clean it.${NC}"
    [ -f "$script_file" ] && echo -e "${BLUE}${BOLD}Removing script '${script_file}'...${NC}" && rm -f "$script_file"
    exit 0
fi

# Main logic to check for distro folder
main_menu # Get distro choice and set variables

if [ -d "$distro" ]; then
    while true; do
        echo -e "${BLUE}${BOLD}Distro folder '${distro}' found.${NC}"
        echo "${BOLD}1) ${GREEN}Fresh Build${NC}${BOLD} (delete existing and configure)${NC}"
        echo "${BOLD}2) ${GREEN}Rebuild${NC}${BOLD} (use existing configuration)${NC}"
        read -p "${BOLD}Enter choice [1/2]: ${NC}" build_type

        case "$build_type" in
            1) fresh_build; break ;;
            2) rebuild_menu; break ;;
            *) echo -e "${RED}${BOLD}Error:${NC} ${RED}${BOLD}Invalid selection. Try again.${NC}" ;;
        esac
    done
else
    # Install build dependencies only for a fresh build
    echo -e "${BLUE}${BOLD}Installing required packages...${NC}"
    sudo apt update -y
    sudo apt install -y "$deps"
    fresh_build
fi

# Final cleanup
cd ..
echo -e "${BLUE}${BOLD}Removing this script '${script_file}'...${NC}"
rm -f "$script_file"
