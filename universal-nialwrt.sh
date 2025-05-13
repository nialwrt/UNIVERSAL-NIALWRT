#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Get script name
script_file="$(basename "$0")"

# Clear screen and print title
clear
echo -e "${BLUE}${BOLD}UNIVERSAL-NIALWRT${NC}"
echo -e "${BLUE}Select your desired firmware distribution:${NC}"
echo "1) OpenWrt"
echo "2) OpenWrt-IPQ"
echo "3) ImmortalWrt"
read -p "Enter choice [1/2/3]: " choice

# Set repo and dependencies
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

# Cleanup mode
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}${BOLD}Cleaning up...${NC}"
    [ -d "$distro" ] && echo -e "${BLUE}Removing '${distro}' directory...${NC}" && rm -rf "$distro"
    [ -f "$script_file" ] && echo -e "${BLUE}Removing script '${script_file}'...${NC}" && rm -f "$script_file"
    exit 0
fi

# Install build dependencies
echo -e "${BLUE}Installing required packages...${NC}"
sudo apt update -y
sudo apt install -y "$deps"

# Remove old directory if exists
[ -d "$distro" ] && echo -e "${BLUE}Removing previous '${distro}' directory...${NC}" && rm -rf "$distro"

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

# Open menuconfig
echo -e "${BLUE}Opening ${BOLD}menuconfig${NC}${BLUE}...${NC}"
make menuconfig

# Build loop
while true; do
    echo -e "${BLUE}Starting build...${NC}"
    start_time=$(date +%s)

    if make -j"$(nproc)"; then
        echo -e "${GREEN}${BOLD}Build completed successfully.${NC}"
        break
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Build failed. Retrying with verbose output...${NC}"
        make -j1 V=s

        echo -e "${RED}Please fix the error, then press Enter to continue...${NC}"
        read -r

        # Feeds recovery
        while true; do
            ./scripts/feeds update -a && ./scripts/feeds install -a && break
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please fix and press Enter...${NC}"
            read -r
        done

        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig
        read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} again? [y/N]: ${NC})" mc
        if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
            make menuconfig
        fi
    fi

    # Duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    echo -e "${BLUE}Build duration: ${BOLD}${hours} hour(s)${NC}${BLUE} and ${BOLD}${minutes} minute(s)${NC}${BLUE}.${NC}"
done

# Final cleanup
cd ..
echo -e "${BLUE}Removing this script '${script_file}'...${NC}"
rm -f "$script_file"
