#!/bin/bash

# Define color codes (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'
YELLOW='\033[0;33m'

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

# Function to install build dependencies
install_deps() {
    local deps="$1"
    echo -e "${BLUE}\n--- Installing required packages ---${NC}"
    sudo apt update -y
    sudo apt install -y "$deps"
    if [ $? -ne 0 ]; then
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to install dependencies. Exiting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Dependency installation complete.${NC}"
}

# Function to setup feeds
setup_feeds() {
    echo -e "${BLUE}\n--- Setting up feeds ---${NC}"
    # Prompt for custom feeds FIRST, before update/install
    echo -e "${BLUE}You may now add custom feeds manually (e.g., by editing feeds.conf.default).${NC}"
    echo -ne "$(echo -e ${BLUE}Press Enter to continue when done...${NC})"
    read temp # Use read biasa

    # Run feeds update and install, with retry logic
     while true; do
        echo -e "${BLUE}Running ./scripts/feeds update -a and ./scripts/feeds install -a...${NC}"
        if ./scripts/feeds update -a && ./scripts/feeds install -a; then
            echo -e "${GREEN}Feeds update/install successful.${NC}"
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue.${NC}"
            echo -ne "$(echo -e ${BLUE}Press Enter to retry or Ctrl+C to exit...${NC})"
            read -r # Tunggu input setelah pesan error
        fi
    done
}

# Function to select and checkout git branch/tag
select_and_checkout_git() {
    echo -e "${BLUE}\n--- Git Branches and Tags ---${NC}"
    echo -e "${BLUE}Available branches:${NC}"
    git branch -a
    echo -e "${BLUE}Available tags:${NC}"
    git tag | sort -V

    echo -e "${BLUE}Select a branch or tag to checkout:${NC}"
    while true; do
        echo -ne "${BLUE}Enter a branch or tag: ${NC}"
        read TARGET_TAG
        if git checkout "$TARGET_TAG"; then
            echo -e "${GREEN}Successfully checked out ${TARGET_TAG}.${NC}"
            break
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Try again.${NC}"
        fi
    done
}

# Function to apply seed config (e.g., for IPQ)
apply_seed_config() {
    local distro_type="$1"
     # Assuming "openwrt-ipq" is the one needing a specific seed config
    if [[ "$distro_type" == "openwrt-ipq" ]]; then
        echo -e "${BLUE}\n--- Applying Seed Config (IPQ specific) ---${NC}"
        # Make sure the seed config file exists in the expected location relative to the script
        if [[ -f "../nss-setup/config-nss.seed" ]]; then
             echo -e "${BLUE}Applying pre-seeded .config from '../nss-setup/config-nss.seed'...${NC}"
             cp "../nss-setup/config-nss.seed" .config
             echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
             make defconfig
             echo -e "${GREEN}Seed config applied and defconfig run.${NC}"
        else
             echo -e "${YELLOW}${BOLD}Warning:${NC} ${YELLOW}Seed config file '../nss-setup/config-nss.seed' not found.${NC}"
             echo -e "${YELLOW}You will need to configure manually in menuconfig.${NC}"
             echo -ne "$(echo -e ${BLUE}Press Enter to continue...${NC})"
             read # Use read biasa
        fi
    fi
}


# Function to run make menuconfig
run_menuconfig() {
    echo -e "${BLUE}\n--- Opening menuconfig ---${NC}"
    echo -e "${BLUE}Opening ${BOLD}menuconfig${NC}${BLUE} for configuration.${NC}"
    echo -ne "$(echo -e ${BLUE}Press Enter to open menuconfig...${NC})"
    read # Use read biasa
    make menuconfig
}


# Function to start the build process
start_build() {
    echo -e "${BLUE}\n--- Starting Build ---${NC}"
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
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Build failed.${NC}"
        echo -e "${RED}\n--- Build Error Details (Verbose Output) ---${NC}"
        make -j1 V=s # Run with verbose output to show errors

        echo -e "${RED}\n--- Build Error Recovery ---${NC}"
        echo -e "${RED}Please fix the error(s) based on the verbose output.${NC}"
        echo -ne "$(echo -e ${BLUE}Press Enter to continue for recompile attempt or Ctrl+C to exit...${NC})"
        read -r

        echo -e "${BLUE}\n--- Running make defconfig for recovery ---${NC}"
        echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig (saat error recovery)
        echo -e "${BLUE}\n--- Menuconfig for recovery ---${NC}"
        echo -ne "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} to re-select packages after error? [y/N]: ${NC})"
        read mc_retry
        if [[ "$mc_retry" == "y" || "$mc_retry" == "Y" ]]; then
             echo -e "${BLUE}Opening menuconfig...${NC}"
            make menuconfig
        fi

        echo -e "${BLUE}\n--- Attempting rebuild after error ---${NC}"
        echo -e "${BLUE}Attempting rebuild...${NC}"
        # Use -k to continue as much as possible after an error during the retry
        if make -j"$(nproc)" -k; then
            echo -e "${GREEN}${BOLD}Rebuild completed successfully after error recovery.${NC}"
            # Duration (re-calculate from start_time of the *first* attempt)
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            hours=$((duration / 3600))
            minutes=$(((duration % 3600) / 60))
            seconds=$((duration % 60))
            echo -e "${BLUE}Total duration including retry: ${BOLD}${hours} hour(s)${NC}${BLUE}, ${BOLD}${minutes} minute(s)${NC}${BLUE}, and ${BOLD}${seconds} second(s)${NC}${BLUE}.${NC}"
            return 0 # Indicate success
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Rebuild failed again. Please check the build log carefully.${NC}"
            return 1 # Indicate failure
        fi
    fi
}

# Function to perform common build steps after cloning or entering existing dir
# Assumes script is already in the source directory
perform_build_steps() {
    local distro_type="$1"
    setup_feeds
    select_and_checkout_git
    apply_seed_config "$distro_type" # Pass distro type to apply_seed_config
    run_menuconfig
    start_build
}

# --- Main Script ---
clear
print_banner

# --- Step 1: Select Distro Type ---
echo -e "${BLUE}\n--- Select Firmware Distribution ---${NC}"
echo "1) OpenWrt"
echo "2) OpenWrt-IPQ"
echo "3) ImmortalWrt"
echo -ne "${BLUE}Enter your choice [1/2/3]: ${NC}"
read distro_choice

local distro_name repo_url deps_list

if [[ "$distro_choice" == "1" ]]; then
    distro_name="openwrt"
    repo_url="https://github.com/openwrt/openwrt.git"
    deps_list="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
elif [[ "$distro_choice" == "2" ]]; then
    distro_name="openwrt-ipq"
    repo_url="https://github.com/qosmio/openwrt-ipq.git"
    deps_list="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget"
elif [[ "$distro_choice" == "3" ]]; then
    distro_name="immortalwrt"
    repo_url="https://github.com/immortalwrt/immortalwrt.git"
    deps_list="ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd"
else
    echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting.${NC}"
    exit 1
fi

# --- Step 2: Install Dependencies ---
install_deps "$deps_list"

# --- Step 3: Check if Directory Exists and Determine Action ---
if [[ -d "$distro_name" ]]; then
    # Directory exists, ask Fresh or Recompile
    echo -e "${BLUE}\n--- Directory Exists: ${distro_name} ---${NC}"
    echo -e "${YELLOW}Warning:${NC} ${YELLOW}Directory '${distro_name}' already exists.${NC}"
    echo -e "${BLUE}What do you want to do?${NC}"
    echo "1) Fresh build (Remove existing directory and clone fresh)"
    echo "2) Recompile (Update/build within the existing directory)"
    echo -ne "${BLUE}Enter your choice [1/2]: ${NC}"
    read action_choice

    if [[ "$action_choice" == "1" ]]; then
        # --- Action: Fresh Build (Remove & Clone) ---
        echo -e "${BLUE}\n--- Performing Fresh Build (Remove & Clone) for ${distro_name} ---${NC}"
        echo -e "${YELLOW}Warning:${NC} ${YELLOW}About to remove directory '${distro_name}'.${NC}"
        echo -ne "$(echo -e ${YELLOW}Are you sure? [y/N]: ${NC})"
        read confirm_remove
        if [[ "$confirm_remove" == "y" || "$confirm_remove" == "Y" ]]; then
            echo -e "${BLUE}Removing existing directory '${distro_name}'...${NC}"
            rm -rf "$distro_name"
            if [ $? -ne 0 ]; then
                 echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to remove directory '${distro_name}'. Exiting.${NC}"
                 exit 1
            fi
        else
            echo -e "${BLUE}Removal cancelled. Exiting.${NC}"
            exit 0 # Exit gracefully if user cancels removal
        fi

        echo -e "${BLUE}Cloning repository ${repo_url} into ${distro_name}...${NC}"
        git clone "$repo_url" "$distro_name"
         if [ $? -ne 0 ]; then
             echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to clone repository. Exiting.${NC}"
             exit 1
         fi

        # Enter source directory and perform build steps
        cd "$distro_name" || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to change directory to '$distro_name'. Exiting.${NC}"; exit 1; }
        perform_build_steps "$distro_name"
        cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; } # Go back

    elif [[ "$action_choice" == "2" ]]; then
        # --- Action: Recompile ---
        echo -e "${BLUE}\n--- Performing Recompile for ${distro_name} ---${NC}"
        # Enter source directory
        cd "$distro_name" || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to change directory to '$distro_name'. Exiting.${NC}"; exit 1; }

        # Ask user for recompile mode within the selected directory
        echo -e "${BLUE}Recompile mode:${NC}"
        echo "1) Recompile with current configuration (faster)"
        echo "2) Recompile and update/install feeds (for version change or new feeds)"
        echo -ne "${BLUE}Enter your choice [1/2]: ${NC}"
        read recompile_mode

        if [[ "$recompile_mode" == "1" ]]; then
            echo -e "${BLUE}\n--- Recompiling with current configuration ---${NC}"
            echo -e "${BLUE}Running '${BOLD}make defconfig${NC}${BLUE}'...${NC}"
            make defconfig
            start_build
        elif [[ "$recompile_mode" == "2" ]]; then
            echo -e "${BLUE}\n--- Recompiling with feeds update ---${NC}"
            # Perform the full build steps including feeds update
            perform_build_steps "$distro_name" # This includes feeds, checkout, config, build
        else
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Exiting.${NC}"
            cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; }
            exit 1
        fi
         cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; } # Go back

    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid choice. Exiting.${NC}"
        exit 1
    fi

else
    # --- Directory does NOT exist, perform Fresh Build (Clone directly) ---
    echo -e "${BLUE}\n--- Directory Does Not Exist: ${distro_name} ---${NC}"
    echo -e "${BLUE}Directory '${distro_name}' not found. Performing a fresh clone and build.${NC}"

    echo -e "${BLUE}Cloning repository ${repo_url} into ${distro_name}...${NC}"
    git clone "$repo_url" "$distro_name"
     if [ $? -ne 0 ]; then
         echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to clone repository. Exiting.${NC}"
         exit 1
     fi

    # Enter source directory and perform build steps
    cd "$distro_name" || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to change directory to '$distro_name'. Exiting.${NC}"; exit 1; }
    perform_build_steps "$distro_name"
    cd .. || { echo -e "${RED}${BOLD}Error:${NC} ${RED}Failed to return to original directory.${NC}"; exit 1; } # Go back
fi

echo -e "${BLUE}\n--- Script finished ---${NC}"
