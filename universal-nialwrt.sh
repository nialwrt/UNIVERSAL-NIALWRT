#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Get script name
script_file="$(basename "$0")"

# Function to print banner
print_banner() {
    echo -e "\e[34m--------------------------------------\e[0m"
    echo -e "\e[34m  UNIVERSAL-NIALWRT Firmware Build  \e[0m"
    echo -e "\e[34m  by nialwrt                        \e[0m"
    echo -e "\e[34m  Telegram: @NIALVPN                 \e[0m"
    echo -e "\e[34m--------------------------------------\e[0m"
}

# Function to perform a fresh build (disc clean)
fresh_build() {
    echo -e "${BLUE}${BOLD}Performing a fresh build...${NC}"
    # Pilih distribusi
    echo -e "${BLUE}Select firmware distribution:${NC}"
    echo "1) OpenWrt"
    echo "2) OpenWrt-IPQ"
    echo "3) ImmortalWrt"
    read -p "Enter choice [1/2/3]: " choice

    # Set repo and dependencies
    local distro repo deps
    if [[ "$choice" == "1" ]]; then
        distro="openwrt"
        repo="https://github.com/openwrt/openwrt.git"
        deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
    elif [[ "$choice" == "2" ]]; then
        distro="openwrt-ipq"
        repo="https://github.com/qosmio/openwrt-ipq.git"
        deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
    elif [[ "$choice" == "3" ]]; then
        distro="immortalwrt"
        repo="https://github.com/immortalwrt/immortalwrt.git"
        deps="ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd"
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting.${NC}"
        exit 1
    fi

    # Install build dependencies
    echo -e "${BLUE}Installing required packages...${NC}"
    sudo apt update -y
    sudo apt install -y "$deps"

    # Remove old directory if exists (sudah dipindahkan ke main script)
    # [ -d "$distro" ] && echo -e "${BLUE}Removing previous '${distro}' directory...${NC}" && rm -rf "$distro"

    # Clone selected repo
    echo -e "${BLUE}Cloning repository...${NC}"
    git clone "$repo" "$distro"

    # Enter source directory
    cd "$distro"

    # Initial feeds setup
    echo -e "${BLUE}Setting up feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a

    # Prompt for custom feeds
    echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
    read -p "Press Enter to continue..." temp

    # Re-run feeds in loop if error
    while true; do
        ./scripts/feeds update -a && ./scripts/feeds install -a && break
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
        read -r
    done

    # Show branches and tags
    echo -e "${BLUE}Available branches:${NC}"
    git branch -a
    echo -e "${BLUE}Available tags:${NC}"
    git tag | sort -V

    # Select tag or branch
    while true; do
        echo -ne "${BLUE}Enter a branch or tag to checkout: ${NC}"
        read TARGET_TAG
        if git checkout "$TARGET_TAG"; then
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Try again.${NC}"
        fi
    done

    # Apply seed config if needed
    if [[ "$choice" == "2" ]]; then
        echo -e "${BLUE}Applying pre-seeded .config...${NC}"
        cp nss-setup/config-nss.seed .config
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig
    fi

    # Open menuconfig (WAJIB untuk fresh build)
    echo -e "${BLUE}Opening ${BOLD}menuconfig${NC}${BLUE}...${NC}"
    make menuconfig

    # Start build
    start_build
}

# Function to perform a recompile for a specific distro
recompile() {
    local distro_dir="$1"
    echo -e "${BLUE}${BOLD}Performing a recompile for ${distro_dir}...${NC}"

    # Check if the directory exists
    if [[ ! -d "$distro_dir" ]]; then
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Directory '${distro_dir}' not found. Exiting recompile.${NC}"
        return 1
    fi

    # Enter the distro directory
    cd "$distro_dir"

    # Feeds update and install (initial)
    echo -e "${BLUE}Updating and installing feeds...${NC}"
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    # Prompt for custom feeds BEFORE branch/tag selection
    echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
    read -p "Press Enter to continue after adding feeds..." temp

    # Re-run feeds update and install AFTER user input
    echo -e "${BLUE}Updating and installing feeds again...${NC}"
    while true; do
        ./scripts/feeds update -a && ./scripts/feeds install -a && break
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
        read -r
    done

    # Show branches and tags
    echo -e "${BLUE}Current branch/tag:${NC}"
    git branch --show-current
    echo -e "${BLUE}Available branches:${NC}"
    git branch -a
    echo -e "${BLUE}Available tags:${NC}"
    git tag | sort -V

    # Select tag or branch
    while true; do
        echo -ne "${BLUE}Enter a branch or tag to checkout (leave blank to keep current): ${NC}"
        read TARGET_TAG
        if [[ -z "$TARGET_TAG" ]]; then
            echo -e "${BLUE}Keeping current branch/tag.${NC}"
            break
        elif git checkout "$TARGET_TAG"; then
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Try again.${NC}"
        fi
    done

    # Run make defconfig
    echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
    make defconfig

    # Ask if user wants to open menuconfig (PILIHAN untuk recompile)
    read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages? [y/N]: ${NC})" mc
    if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
        make menuconfig
    fi

    # Start build
    start_build

    cd .. # Go back to the script's original directory
}

# Function to start the build process
start_build() {
    echo -e "${BLUE}Starting build with ${BOLD}-j$(nproc)${NC}${BLUE}...${NC}"
    start_time=$(date +%s)

    if make -j"$(nproc)"; then
        echo -e "${GREEN}${BOLD}Build completed successfully.${NC}"
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Build failed. Retrying with verbose output...${NC}"
        make -j1 V=s

        echo -e "${RED}Please fix the error, then press Enter to continue for recompile...${NC}"
        read -r

        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig (PILIHAN saat error recovery)
        read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages? [y/N]: ${NC})" mc_retry
        if [[ "$mc_retry" == "y" || "$mc_retry" == "Y" ]]; then
            make menuconfig
        fi

        echo -e "${BLUE}Attempting rebuild...${NC}"
        make -j"$(nproc)" # Coba rebuild lagi setelah defconfig dan menuconfig (opsional)

        if make -j"$(nproc)"; then
            echo -e "${GREEN}${BOLD}Rebuild completed successfully after error recovery.${NC}"
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Rebuild failed again. Please check the build log carefully.${NC}"
        fi
        break # Keluar dari loop setelah satu kali percobaan rebuild setelah error
    fi

    # Duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    echo -e "${BLUE}Build duration: ${BOLD}${hours} hour(s)${NC}${BLUE} and ${BOLD}${minutes} minute(s)${NC}${BLUE}.${NC}"
    break # Keluar dari loop jika build awal berhasil
}

# --- Main Script ---
clear
print_banner

declare -a existing_dirs=()
if [[ -d "openwrt" ]]; then existing_dirs+=("openwrt"); fi
if [[ -d "openwrt-ipq" ]]; then existing_dirs+=("openwrt-ipq"); fi
if [[ -d "immortalwrt" ]]; then existing_dirs+=("immortalwrt"); fi

if [[ ${#existing_dirs[@]} -gt 0 ]]; then
    echo -e "${BLUE}Found existing firmware directories:${NC}"
    echo "What do you want to do?"
    echo "0) Recompile"
    echo "1) Fresh build"
    read -p "Enter your choice [0/1]: " build_choice

    if [[ "$build_choice" == "0" ]]; then
        echo -e "${BLUE}Which distro do you want to recompile?${NC}"
        for i in "${!existing_dirs[@]}"; do
            echo "$((i+1))) ${existing_dirs[$i]}"
        done
        read -p "Enter the number of the distro to recompile: " recompile_choice
        if [[ "$recompile_choice" -ge 1 && "$recompile_choice" -le "${#existing_dirs[@]}" ]]; then
            selected_dir="${existing_dirs[$((recompile_choice-1))]}"
            echo -e "${BLUE}Recompiling ${BOLD}${selected_dir}${NC}${BLUE}...${NC}"
            recompile "$selected_dir"
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting.${NC}"
            exit 1
        fi
    elif [[ "$build_choice" == "1" ]]; then
        echo -e "${BLUE}Which distro do you want to perform a fresh build on?${NC}"
        for i in "${!existing_dirs[@]}"; do
            echo "$((i+1))) ${existing_dirs[$i]}"
        done
        read -p "Enter the number of the distro to fresh build: " fresh_build_choice
        if [[ "$fresh_build_choice" -ge 1 && "$fresh_build_choice" -le "${#existing_dirs[@]}" ]]; then
            selected_
