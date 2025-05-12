#!/bin/bash

# Define color codes
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# Get script file name
script_file="$(basename "$0")"

# Clear the screen and show title
clear
echo -e "${BLUE}UNIVERSAL-NIALWRT${NC}"
echo -e "${BLUE}Select the firmware distribution you want to build:${NC}"
echo "1) OpenWrt"
echo "2) OpenWrt-IPQ"
echo "3) ImmortalWrt"
read -p "Enter your choice [1/2/3]: " choice

# Define repository and dependencies based on choice
if [[ "$choice" == "1" ]]; then
    distro="openwrt"
    repo="https://github.com/openwrt/openwrt.git"
    deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext \
git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
elif [[ "$choice" == "2" ]]; then
    distro="openwrt-ipq"
    repo="https://github.com/qosmio/openwrt-ipq.git"
    deps="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext \
git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
elif [[ "$choice" == "3" ]]; then
    distro="immortalwrt"
    repo="https://github.com/immortalwrt/immortalwrt.git"
    deps="ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext \
gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 \
libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev \
libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev \
lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 \
python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync \
scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto \
xxd zlib1g-dev zstd"
else
    echo -e "${RED}Invalid choice. Exiting.${NC}"
    exit 1
fi

# Optional: cleanup mode
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}Cleaning up directories and this script...${NC}"
    [ -d "$distro" ] && echo -e "${BLUE}Removing '${distro}' directory...${NC}" && rm -rf "$distro"
    [ -f "$script_file" ] && echo -e "${BLUE}Removing script file '${script_file}'...${NC}" && rm -f "$script_file"
    exit 0
fi

# Install required packages
echo -e "${BLUE}Installing required build dependencies...${NC}"
sudo apt update -y
sudo apt install -y $deps

# Remove old directory if it exists
[ -d "$distro" ] && echo -e "${BLUE}Removing existing '${distro}' directory...${NC}" && rm -rf "$distro"

# Clone the selected repository
echo -e "${BLUE}Cloning repository from GitHub...${NC}"
git clone $repo $distro

# Enter the build directory
cd $distro

# Update and install feeds
echo -e "${BLUE}Initializing package feeds...${NC}"
./scripts/feeds update -a && ./scripts/feeds install -a

# Pause for adding custom feeds
echo -e "${BLUE}You may now add custom feeds if needed.${NC}"
read -p "Press [Enter] to continue..." temp

# Retry if feeds update/install fails
while ! ./scripts/feeds update -a && ./scripts/feeds install -a; do
    echo -e "${RED}Feeds update and install failed. Please fix any issues in 'feeds.conf.default' and press Enter to retry...${NC}"
    read -r
done

# Show available branches and tags
echo -e "${BLUE}Available branches:${NC}"
git branch -a
echo -e "${BLUE}Available tags:${NC}"
git tag | sort -V

# Prompt user to checkout branch or tag
while true; do
    echo -ne "${BLUE}Enter a branch or tag to checkout: ${NC}"
    read TARGET_TAG
    if git checkout $TARGET_TAG; then
        break
    else
        echo -e "${RED}Invalid branch/tag. Please try again.${NC}"
    fi
done

# If openwrt-ipq, apply config
if [[ "$choice" == "2" ]]; then
    echo -e "${BLUE}Applying preseeded .config for OpenWrt-IPQ...${NC}"
    cp nss-setup/config-nss.seed .config
fi

# Only for openwrt-ipq, run make defconfig on first compile
if [[ "$choice" == "2" ]]; then
    echo -e "${BLUE}Running 'make defconfig' for OpenWrt-IPQ...${NC}"
    make defconfig
fi

# Launch the build config menu
echo -e "${BLUE}Opening configuration menu...${NC}"
make menuconfig

# Recompile loop until success
while true; do
    echo -e "${BLUE}Starting the build process...${NC}"
    start_time=$(date +%s)
    if make -j"$(nproc)"; then
        echo -e "${GREEN}Build completed successfully.${NC}"
        break
    else
        echo -e "${RED}Build failed. Retrying with detailed output...${NC}"
        make -j1 V=s
        echo -e "${RED}Error encountered. Please fix the issue and press Enter to continue...${NC}"
        read -r

        # Retry feeds update/install if there's an issue
        while ! ./scripts/feeds update -a && ./scripts/feeds install -a; do
            echo -e "${RED}Feeds update and install failed. Please fix any issues in 'feeds.conf.default' and press Enter to retry...${NC}"
            read -r
        done

        # Run make defconfig for all distros after fix
        echo -e "${BLUE}Running 'make defconfig' to initialize clean configuration after failure...${NC}"
        make defconfig
    fi
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    echo -e "${BLUE}Build attempt duration: ${hours} hour(s) and ${minutes} minute(s).${NC}"
    echo -e "${RED}You may fix the issue, then press Enter to retry build...${NC}"
    read -r
done

# Clean up script
cd ..
echo -e "${BLUE}Cleaning up this script file '${script_file}'...${NC}"
rm -f "$script_file"
