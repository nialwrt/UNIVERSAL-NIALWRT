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

    # Feeds update and install
    echo -e "${BLUE}Updating and installing feeds...${NC}"
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    # Prompt for custom feeds BEFORE branch/tag selection
    echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
    read -p "Press Enter to continue after adding feeds..." temp

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
