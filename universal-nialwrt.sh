#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'
YELLOW='\033[0;33m' # Tambahkan warna kuning untuk peringatan

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
    echo -e "${BLUE}${BOLD}\n--- Performing a fresh build ---${NC}" # Tambah spasi dan header

    # Pilih distribusi
    echo -e "${BLUE}Select firmware distribution:${NC}"
    echo "1) OpenWrt"
    echo "2) OpenWrt-IPQ"
    echo "3) ImmortalWrt"
    echo -ne "${BLUE}Enter choice [1/2/3]: ${NC}" # Gunakan echo -ne untuk prompt
    read choice # Gunakan read biasa

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
    echo -e "${BLUE}\n--- Installing required packages ---${NC}" # Tambah spasi dan header
    sudo apt update -y
    sudo apt install -y "$deps"

    # Clone selected repo
    echo -e "${BLUE}\n--- Cloning repository ---${NC}" # Tambah spasi dan header
    # Add a check/prompt to remove existing directory if it exists before cloning
    if [[ -d "$distro" ]]; then
        echo -e "${YELLOW}Warning:${NC} ${YELLOW}Directory '${distro}' already exists.${NC}"
        echo -ne "$(echo -e ${YELLOW}Do you want to remove it and clone fresh? [y/N]: ${NC})" # Gunakan echo -ne untuk prompt
        read remove_existing # Gunakan read biasa
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
    echo -e "${BLUE}\n--- Setting up feeds ---${NC}" # Tambah spasi dan header
    if ./scripts/feeds update -a && ./scripts/feeds install -a; then
        echo -e "${GREEN}Feeds setup successful.${NC}"
    else
        # Re-run feeds in loop if error
        while true; do
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Initial feeds update/install failed. Please address the issue.${NC}"
            echo -ne "$(echo -e ${BLUE}Press Enter to retry or Ctrl+C to exit...${NC})"
            read -r # Tunggu input setelah pesan error
            if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                echo -e "${GREEN}Feeds setup successful after retry.${NC}"
                break
            fi
        done
    fi


    # Prompt for custom feeds
    echo -e "${BLUE}\n--- Custom Feeds ---${NC}" # Tambah spasi dan header
    echo -e "${BLUE}You may now add custom feeds manually (e.g., by editing feeds.conf.default).${NC}"
    echo -ne "$(echo -e ${BLUE}Press Enter to continue when done...${NC})" # Gunakan echo -ne untuk prompt
    read temp # Gunakan read biasa

    # Re-run feeds in loop if error (after custom feeds)
    echo -e "${BLUE}\n--- Re-checking feeds after custom additions ---${NC}" # Tambah spasi dan header
     while true; do
        if ./scripts/feeds update -a && ./scripts/feeds install -a; then
            echo -e "${GREEN}Feeds update/install successful.${NC}"
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed after custom feeds. Please address the issue.${NC}"
            echo -ne "$(echo -e ${BLUE}Press Enter to retry or Ctrl+C to exit...${NC})"
            read -r # Tunggu input setelah pesan error
        fi
    done


    # Show branches and tags
    echo -e "${BLUE}\n--- Git Branches and Tags ---${NC}" # Tambah spasi dan header
    echo -e "${BLUE}Available branches:${NC}"
    git branch -a
    echo -e "${BLUE}Available tags:${NC}"
    git tag | sort -V

    # Select tag or branch
    echo -e "${BLUE}Select a branch or tag to checkout:${NC}"
    while true; do
        echo -ne "${BLUE}Enter a branch or tag: ${NC}" # Gunakan echo -ne untuk prompt
        read TARGET_TAG # Gunakan read biasa
        if git checkout "$TARGET_TAG"; then
            echo -e "${GREEN}Successfully checked out ${TARGET_TAG}.${NC}"
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Try again.${NC}"
        fi
    done

    # Apply seed config if needed
    # Assuming choice '2' corresponds to openwrt-ipq based on the original script logic
    if [[ "$choice" == "2" ]]; then
        echo -e "${BLUE}\n--- Applying Seed Config (IPQ specific) ---${NC}" # Tambah spasi dan header
        # Make sure the seed config file exists in the expected location relative to the script
        if [[ -f "../nss-setup/config-nss.seed" ]]; then
             echo -e "${BLUE}Applying pre-seeded .config from '../nss-setup/config-nss.seed'...${NC}"
             cp "../nss-setup/config-nss.seed" .config
             echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
             make defconfig
             echo -e "${GREEN}Seed config applied and defconfig run.${NC}"
        else
             echo -e "${RED}${BOLD}Error:${NC} ${RED}Seed config file '../nss-setup/config-nss.seed' not found.${NC}"
             echo -ne "$(echo -e ${BLUE}Press Enter to continue and run menuconfig to configure manually...${NC})" # Gunakan echo -ne untuk prompt
             read # Gunakan read biasa
             # Do not exit, allow user to configure via menuconfig
        fi
    fi

    # Open menuconfig (WAJIB untuk fresh build)
    echo -e "${BLUE}\n--- Opening menuconfig ---${NC}" # Tambah spasi dan header
    echo -e "${BLUE}Opening ${BOLD}menuconfig${NC}${BLUE} for configuration.${NC}"
    echo -ne "$(echo -e ${BLUE}Press Enter to open menuconfig...${NC})" # Gunakan echo -ne untuk prompt
    read # Gunakan read biasa
    make menuconfig

    # Start build
    echo -e "${BLUE}\n--- Starting Build ---${NC}" # Tambah spasi dan header
    start_build

    cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; } # Go back to the script's original directory
}

# Function to perform a recompile for a specific distro
recompile() {
    local distro_dir="$1"
    echo -e "${BLUE}${BOLD}\n--- Performing a recompile for ${distro_dir} ---${NC}" # Tambah spasi dan header

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
    echo -ne "${BLUE}Enter your choice [1/2]: ${NC}" # Gunakan echo -ne untuk prompt
    read recompile_mode # Gunakan read biasa

    if [[ "$recompile_mode" == "1" ]]; then
        # Recompile dengan konfigurasi saat ini
        echo -e "${BLUE}\n--- Recompiling with current configuration ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig
        start_build
    elif [[ "$recompile_mode" == "2" ]]; then
        # Feeds update and install
        echo -e "${BLUE}\n--- Updating and installing feeds ---${NC}" # Tambah spasi dan header
        ./scripts/feeds update -a
        ./scripts/feeds install -a

        # Prompt for custom feeds
        echo -e "${BLUE}\n--- Custom Feeds ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}You may now add custom feeds manually (e.g., by editing feeds.conf.default).${NC}"
        echo -ne "$(echo -e ${BLUE}Press Enter to continue after adding feeds...${NC})" # Gunakan echo -ne untuk prompt
        read temp # Gunakan read biasa

        # Re-run feeds in loop if error (after custom feeds)
        echo -e "${BLUE}\n--- Re-checking feeds after custom additions ---${NC}" # Tambah spasi dan header
         while true; do
            if ./scripts/feeds update -a && ./scripts/feeds install -a; then
                 echo -e "${GREEN}Feeds update/install successful.${NC}"
                 break
            else
                echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed after custom feeds. Please address the issue.${NC}"
                echo -ne "$(echo -e ${BLUE}Press Enter to retry or Ctrl+C to exit...${NC})" # Gunakan echo -ne untuk prompt
                read -r # Tunggu input setelah pesan error
            fi
        done

        # Show branches and tags
        echo -e "${BLUE}\n--- Git Branches and Tags ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}Current branch/tag:${NC}"
        git branch --show-current
        echo -e "${BLUE}Available branches:${NC}"
        git branch -a
        echo -e "${BLUE}Available tags:${NC}"
        git tag | sort -V

        # Select tag or branch
        echo -e "${BLUE}Select a branch or tag to checkout:${NC}"
        while true; do
            echo -ne "${BLUE}Enter a branch or tag to checkout (leave blank to keep current): ${NC}" # Gunakan echo -ne untuk prompt
            read TARGET_TAG # Gunakan read biasa
            if [[ -z "$TARGET_TAG" ]]; then
                echo -e "${BLUE}Keeping current branch/tag.${NC}"
                break
            elif git checkout "$TARGET_TAG"; then
                echo -e "${GREEN}Successfully checked out ${TARGET_TAG}.${NC}"
                break
            else
                echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Try again.${NC}"
            fi
        done

        # Run make defconfig
        echo -e "${BLUE}\n--- Running make defconfig ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig
        echo -e "${BLUE}\n--- Menuconfig ---${NC}" # Tambah spasi dan header
        echo -ne "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages? [y/N]: ${NC})" # Gunakan echo -ne untuk prompt
        read mc # Gunakan read biasa
        if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
             echo -e "${BLUE}Opening menuconfig...${NC}"
            make menuconfig
        fi

        # Start build
        echo -e "${BLUE}\n--- Starting Build ---${NC}" # Tambah spasi dan header
        start_build
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting recompile.${NC}"
        cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; }
        return 1
    fi

    cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; } # Go back to the script's original directory
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

        echo -e "${RED}\n--- Build Error Recovery ---${NC}" # Tambah spasi dan header
        echo -e "${RED}Please fix the error, then press Enter to continue for recompile attempt...${NC}"
        read -r

        echo -e "${BLUE}\n--- Running make defconfig for recovery ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig (saat error recovery)
        echo -e "${BLUE}\n--- Menuconfig for recovery ---${NC}" # Tambah spasi dan header
        echo -ne "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages after error? [y/N]: ${NC})" # Gunakan echo -ne untuk prompt
        read mc_retry # Gunakan read biasa
        if [[ "$mc_retry" == "y" || "$mc_retry" == "Y" ]]; then
             echo -e "${BLUE}Opening menuconfig...${NC}"
            make menuconfig
        fi

        echo -e "${BLUE}\n--- Attempting rebuild after error ---${NC}" # Tambah spasi dan header
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

    echo -e "${BLUE}\n--- Choose Action ---${NC}" # Tambah spasi dan header
    echo -e "${BLUE}What do you want to do?${NC}"
    echo "1) Fresh build (Will clone into a new directory, potentially overwriting if it exists)"
    echo "2) Recompile (Update/build within an existing directory)"
    echo -ne "${BLUE}Enter your choice [1/2]: ${NC}" # Gunakan echo -ne untuk prompt
    read build_choice # Gunakan read biasa

    if [[ "$build_choice" == "1" ]]; then
        # Perform a fresh build. The fresh_build function handles selecting the distro type
        # and cloning.
        fresh_build
        # TODO: Consider if the user should select *which* type of fresh build
        # (OpenWrt, IPQ, ImmortalWrt) *after* choosing option 1 here,
        # instead of just calling fresh_build directly which prompts again.
        # For now, calling fresh_build directly is the simplest approach.

    elif [[ "$build_choice" == "2" ]]; then
        # Recompile an existing directory
        echo -e "${BLUE}\n--- Choose Directory to Recompile ---${NC}" # Tambah spasi dan header
        echo -e "${BLUE}Which distro directory do you want to recompile?${NC}"
        # List existing directories again for selection
        for i in "${!existing_dirs[@]}"; do
            echo "$((i+1))) ${existing_dirs[$i]}"
        done
        echo -ne "${BLUE}Enter the number of the distro: ${NC}" # Gunakan echo -ne untuk prompt
        read recompile_choice # Gunakan read biasa

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

echo -e "${BLUE}\nScript finished.${NC}" # Tambah spasi di akhir
