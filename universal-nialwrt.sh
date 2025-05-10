#!/bin/bash

# Define colors
BLUE='\033[1;34m'
NC='\033[0m'

folder="immortalwrt"
script_file="$(basename "$0")"

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}Cleaning up directories and script...${NC}"
    [ -d "$folder" ] && echo -e "${BLUE}Removing '$folder' directory...${NC}" && rm -rf "$folder"
    [ -f "$script_file" ] && echo -e "${BLUE}Removing script file '$script_file'...${NC}" && rm -f "$script_file"
    exit 0
fi

clear
echo -e "${BLUE}"
echo "UNIVERSAL-NIALWRT"
echo -e "${NC}"

# Install dependencies
echo -e "${BLUE}Installing required dependencies...${NC}"
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

# Remove existing ImmortalWrt directory if present
[ -d "$folder" ] && echo -e "${BLUE}Removing existing '$folder' directory...${NC}" && rm -rf "$folder"

# Clone ImmortalWrt repository
repo="https://github.com/immortalwrt/immortalwrt.git"
echo -e "${BLUE}Cloning ImmortalWrt repository...${NC}"
git clone $repo $folder

# Enter ImmortalWrt directory
cd $folder

# Install feeds
echo -e "${BLUE}Setting up feeds...${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# Pause for user to add additional feeds if needed
echo -e "${BLUE}If you have any additional feeds, add them now.${NC}"
read -p "Press [Enter] to continue..."

# Update feeds again
echo -e "${BLUE}Updating all feeds...${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# Show branches and tags
echo -e "${BLUE}Available branches:${NC}"
git branch -a

echo -e "${BLUE}Available tags:${NC}"
git tag | sort -V

# Prompt for target branch/tag
echo -ne "${BLUE}Enter target branch or tag to checkout: ${NC}"
read TARGET_TAG
git checkout $TARGET_TAG

# Open menuconfig without prompt
echo -e "${BLUE}Launching 'make menuconfig'...${NC}"
make menuconfig

# Start build and log output
echo -e "${BLUE}Starting build, logging to 'build.log' and 'error.log'...${NC}"
start_time=$(date +%s)
make -j$(nproc) > build.log 2> error.log
end_time=$(date +%s)

# Build duration
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))
echo -e "${BLUE}Build completed in: ${hours} hour(s) ${minutes} minute(s)${NC}"

# Back to root dir
cd ..

# Delete script
echo -e "${BLUE}Deleting script '$script_file'...${NC}"
rm -f "$script_file"
