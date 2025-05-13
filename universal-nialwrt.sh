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
    echo -e "${BLUE}--------------------------------------${NC}"
    echo -e "${BLUE}  UNIVERSAL-NIALWRT Firmware Build  ${NC}"
    echo -e "${BLUE}  by nialwrt                        ${NC}"
    echo -e "${BLUE}  Telegram: @NIALVPN                 ${NC}"
    echo -e "${BLUE}--------------------------------------${NC}"
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

    # Clone selected repo
    echo -e "${BLUE}Cloning repository...${NC}"
    # Add a check/prompt to remove existing directory if it exists before cloning
    if [[ -d "$distro" ]]; then
        read -p "$(echo -e ${YELLOW}Warning:${NC} ${YELLOW}Directory '${distro}' already exists. Do you want to remove it and clone fresh? [y/N]: ${NC})" remove_existing
        if [[ "$remove_existing" == "y" || "$remove_existing" == "Y" ]]; then
            echo -e "${BLUE}Removing existing directory '${distro}'...${NC}"
            rm -rf "$distro"
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Directory '${distro}' exists and not removed. Cannot perform fresh clone. Exiting.${NC}"
            exit 1
        fi
    fi
    git clone "$repo" "$distro"

    # Enter source directory
    cd "$distro" || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to change directory to '$distro'. Exiting.${NC}"; exit 1; }


    # Initial feeds setup
    echo -e "${BLUE}Setting up feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a

    # Prompt for custom feeds
    echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
    read -p "Press Enter to continue..." temp

    # Re-run feeds in loop if error
    while true; do
        if ./scripts/feeds update -a && ./scripts/feeds install -a; then
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
            read -r
        fi
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
    if [[ "$choice" == "2" ]]; then # Assuming choice '2' corresponds to openwrt-ipq
        echo -e "${BLUE}Applying pre-seeded .config...${NC}"
        # Make sure the seed config file exists in the expected location relative to the script
        if [[ -f "../nss-setup/config-nss.seed" ]]; then
             cp "../nss-setup/config-nss.seed" .config
        else
             echo -e "${RED}${BOLD}Error:${NC} ${RED}Seed config file '../nss-setup/config-nss.seed' not found.${NC}"
             read -p "$(echo -e ${BLUE}Press Enter to continue and run menuconfig to configure manually...${NC})"
             # Do not exit, allow user to configure via menuconfig
        fi
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig
    fi

    # Open menuconfig (WAJIB untuk fresh build)
    echo -e "${BLUE}Opening ${BOLD}menuconfig${NC}${BLUE}...${NC}"
    make menuconfig

    # Start build
    start_build

    cd .. # Go back to the script's original directory
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
    cd "$distro_dir" || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to change directory to '$distro_dir'. Exiting.${NC}"; return 1; }


    # Ask user for recompile mode
    echo -e "${BLUE}Recompile mode:${NC}"
    echo "1) Recompile with current configuration (faster)"
    echo "2) Recompile and update/install feeds (for version change or new feeds)"
    read -p "Enter your choice [1/2]: " recompile_mode

    if [[ "$recompile_mode" == "1" ]]; then
        # Recompile dengan konfigurasi saat ini
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig
        start_build
    elif [[ "$recompile_mode" == "2" ]]; then
        # Feeds update and install
        echo -e "${BLUE}Updating and installing feeds...${NC}"
        ./scripts/feeds update -a
        ./scripts/feeds install -a

        # Prompt for custom feeds
        echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
        read -p "Press Enter to continue after adding feeds..." temp

        # Re-run feeds in loop if error
        while true; do
            if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                 break
            else
                echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
                read -r
            fi
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

        # Ask if user wants to open menuconfig
        read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages? [y/N]: ${NC})" mc
        if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
            make menuconfig
        fi

        # Start build
        start_build
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting recompile.${NC}"
        cd ..
        return 1
    fi

    cd .. # Go back to the script's original directory
    return 0 # Indicate success
}

# Function to start the build process
start_build() {
    echo -e "${BLUE}Starting build with ${BOLD}-j$(nproc)${NC}${BLUE}...${NC}"
    start_time=$(date +%s)

    if make -j"$(nproc)"; then
        echo -e "${GREEN}${BOLD}Build completed successfully.${NC}"
        # Duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        hours=$((duration / 3600))
        minutes=$(((duration % 3600) / 60))
        seconds=$((duration % 60))
        echo -e "${BLUE}Build duration: ${BOLD}${hours} hour(s)${NC}${BLUE}, ${BOLD}${minutes} minute(s)${NC}${BLUE}, and ${BOLD}${seconds} second(s)${NC}${BLUE}.${NC}"
        return 0 # Indicate success
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Build failed. Retrying with verbose output...${NC}"
        make -j1 V=s

        echo -e "${RED}Please fix the error, then press Enter to continue for recompile...${NC}"
        read -r

        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig (saat error recovery)
        read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages? [y/N]: ${NC})" mc_retry
        if [[ "$mc_retry" == "y" || "$mc_retry" == "Y" ]]; then
            make menuconfig
        fi

        echo -e "${BLUE}Attempting rebuild...${NC}"
        # Use -k to continue as much as possible after an error during the retry
        if make -j"$(nproc)" -k; then
            echo -e "${GREEN}${BOLD}Rebuild completed successfully after error recovery.${NC}"
            # Duration
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            hours=$((duration / 3600))
            minutes=$(((duration % 3600) / 60))
            seconds=$((duration % 60))
            echo -e "${BLUE}Build duration: ${BOLD}${hours} hour(s)${NC}${BLUE}, ${BOLD}${minutes} minute(s)${NC}${BLUE}, and ${BOLD}${seconds} second(s)${NC}${BLUE}.${NC}"
            return 0 # Indicate success
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Rebuild failed again. Please check the build log carefully.${NC}"
            return 1 # Indicate failure
        fi
    fi
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
    for i in "${!existing_dirs[@]}"; do
        echo "$((i+1))) ${existing_dirs[$i]}"
    done
    echo -e "${BLUE}What do you want to do?${NC}"
    echo "1) Fresh build (Will clone into a new directory, potentially overwriting if it exists)"
    echo "2) Recompile (Update/build within an existing directory)"
    read -p "Enter your choice [1/2]: " build_choice

    if [[ "$build_choice" == "1" ]]; then
        # Perform a fresh build. The fresh_build function handles selecting the distro type
        # and cloning. Modified fresh_build to prompt for removal if directory exists.
        fresh_build
        # TODO: Consider if the user should select *which* type of fresh build
        # (OpenWrt, IPQ, ImmortalWrt) *after* choosing option 1 here,
        # instead of just calling fresh_build directly which prompts again.
        # For now, calling fresh_build directly simplifies the fix for the syntax error.

    elif [[ "$build_choice" == "2" ]]; then
        # Recompile an existing directory
        echo -e "${BLUE}Which distro do you want to recompile?${NC}"
        # List existing directories again for selection
        for i in "${!existing_dirs[@]}"; do
            echo "$((i+1))) ${existing_dirs[$i]}"
        done
        read -p "Enter the number of the distro to recompile: " recompile_choice
        if [[ "$recompile_choice" -gt 0 && "$recompile_choice" -le ${#existing_dirs[@]} ]]; then
            selected_distro="${existing_dirs[$((recompile_choice-1))]}"
            recompile "$selected_distro"
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid choice. Exiting.${NC}"
        exit 1
    fi
else
    # No existing directories, perform fresh build directly
    echo -e "${BLUE}No existing firmware directories found. Performing a fresh build.${NC}"
    fresh_build
fi

echo -e "${BLUE}Script finished.${NC}"
