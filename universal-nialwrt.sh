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
        echo -e "${BOLD}1) ${GREEN}Fresh Build${NC}${BOLD} (delete existing and configure)${NC}"
        echo -e "${BOLD}2) ${GREEN}Rebuild${NC}${BOLD} (use existing configuration)${NC}"
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
