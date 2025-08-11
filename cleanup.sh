#!/bin/sh

# Magic Scripts Complete Cleanup Tool
# Use this script when Magic Scripts is corrupted or not working properly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="$HOME/.local/bin/ms"
DATA_DIR="$HOME/.local/share/magicscripts"
MAN_DIR="$HOME/.local/share/man/man1"

show_header() {
    echo ""
    echo "${RED}╔═══════════════════════════════════════════════╗${NC}"
    echo "${RED}║         Magic Scripts Cleanup Tool           ║${NC}"
    echo "${RED}║       Complete System Removal & Reset        ║${NC}"
    echo "${RED}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
}

show_what_will_be_removed() {
    echo "${YELLOW}This script will completely remove:${NC}"
    echo ""
    
    echo "${CYAN}Executables:${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        echo "  ${BLUE}✓${NC} $INSTALL_DIR (and all Magic Scripts commands)"
        ls -1 "$INSTALL_DIR" 2>/dev/null | sed 's/^/    - /' || echo "    (empty)"
    else
        echo "  ${YELLOW}○${NC} $INSTALL_DIR (not found)"
    fi
    echo ""
    
    echo "${CYAN}Data Directory:${NC}"
    if [ -d "$DATA_DIR" ]; then
        echo "  ${BLUE}✓${NC} $DATA_DIR"
        echo "    - Configuration files"
        echo "    - Downloaded scripts"
        echo "    - Registry cache"
        echo "    - Installation metadata"
    else
        echo "  ${YELLOW}○${NC} $DATA_DIR (not found)"
    fi
    echo ""
    
    echo "${CYAN}Man Pages:${NC}"
    local man_files_found=false
    for man_file in "$MAN_DIR"/ms*.1; do
        if [ -f "$man_file" ]; then
            if [ "$man_files_found" = false ]; then
                echo "  ${BLUE}✓${NC} Man pages in $MAN_DIR:"
                man_files_found=true
            fi
            echo "    - $(basename "$man_file")"
        fi
    done
    
    if [ "$man_files_found" = false ]; then
        echo "  ${YELLOW}○${NC} No Magic Scripts man pages found"
    fi
    echo ""
    
    echo "${CYAN}Shell Configuration:${NC}"
    local path_modifications_found=false
    for config_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$config_file" ] && grep -q "\.local/bin/ms" "$config_file"; then
            if [ "$path_modifications_found" = false ]; then
                echo "  ${BLUE}✓${NC} PATH modifications will be removed from:"
                path_modifications_found=true
            fi
            echo "    - $(basename "$config_file")"
        fi
    done
    
    if [ "$path_modifications_found" = false ]; then
        echo "  ${YELLOW}○${NC} No PATH modifications found"
    fi
    echo ""
}

confirm_removal() {
    echo "${RED}WARNING: This action cannot be undone!${NC}"
    echo ""
    printf "Are you sure you want to completely remove Magic Scripts? "
    printf "${YELLOW}Type 'yes' to confirm: ${NC}"
    read -r reply
    
    case "$reply" in
        yes|YES)
            echo ""
            echo "${GREEN}Proceeding with cleanup...${NC}"
            return 0
            ;;
        *)
            echo ""
            echo "${BLUE}Cleanup cancelled.${NC}"
            exit 0
            ;;
    esac
}

remove_executables() {
    echo "${CYAN}Removing executables...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        local count=$(ls -1 "$INSTALL_DIR" 2>/dev/null | wc -l | tr -d ' ')
        rm -rf "$INSTALL_DIR"
        echo "  ${GREEN}✓${NC} Removed $count Magic Scripts commands from $INSTALL_DIR"
    else
        echo "  ${YELLOW}○${NC} Install directory not found: $INSTALL_DIR"
    fi
}

remove_data_directory() {
    echo "${CYAN}Removing data directory...${NC}"
    
    if [ -d "$DATA_DIR" ]; then
        # Count items being removed
        local config_count=0
        local script_count=0
        local reg_count=0
        local meta_count=0
        
        [ -f "$DATA_DIR/config" ] && config_count=1
        [ -d "$DATA_DIR/scripts" ] && script_count=$(ls -1 "$DATA_DIR/scripts"/*.sh 2>/dev/null | wc -l | tr -d ' ')
        [ -d "$DATA_DIR/reg" ] && reg_count=$(ls -1 "$DATA_DIR/reg"/*.msreg 2>/dev/null | wc -l | tr -d ' ')
        [ -d "$DATA_DIR/installed" ] && meta_count=$(ls -1 "$DATA_DIR/installed"/*.msmeta 2>/dev/null | wc -l | tr -d ' ')
        
        rm -rf "$DATA_DIR"
        echo "  ${GREEN}✓${NC} Removed data directory: $DATA_DIR"
        echo "    - Configuration files: $config_count"
        echo "    - Script files: $script_count" 
        echo "    - Registry cache: $reg_count"
        echo "    - Metadata files: $meta_count"
    else
        echo "  ${YELLOW}○${NC} Data directory not found: $DATA_DIR"
    fi
}

remove_man_pages() {
    echo "${CYAN}Removing man pages...${NC}"
    
    local removed_count=0
    for man_file in "$MAN_DIR"/ms*.1; do
        if [ -f "$man_file" ]; then
            rm -f "$man_file"
            echo "  ${GREEN}✓${NC} Removed $(basename "$man_file")"
            removed_count=$((removed_count + 1))
        fi
    done
    
    if [ $removed_count -eq 0 ]; then
        echo "  ${YELLOW}○${NC} No Magic Scripts man pages found"
    else
        echo "  ${GREEN}✓${NC} Removed $removed_count man pages"
    fi
}

remove_shell_config() {
    echo "${CYAN}Cleaning shell configuration...${NC}"
    
    local removed_from=0
    
    for config_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ ! -f "$config_file" ]; then
            continue
        fi
        
        # Check if Magic Scripts PATH is present
        if grep -q "\.local/bin/ms" "$config_file"; then
            # Create backup
            cp "$config_file" "${config_file}.magic-scripts-backup"
            
            # Remove Magic Scripts lines
            grep -v "# Magic Scripts" "$config_file" | \
            grep -v "\.local/bin/ms" | \
            grep -v "\.local/share/man" > "${config_file}.tmp"
            
            # Remove empty lines that might be left behind
            awk 'BEGIN{blank=0} /^$/{blank++} !/^$/{for(i=0;i<blank;i++)print ""; blank=0; print}' "${config_file}.tmp" > "$config_file"
            rm -f "${config_file}.tmp"
            
            echo "  ${GREEN}✓${NC} Cleaned $(basename "$config_file") (backup: $(basename "$config_file").magic-scripts-backup)"
            removed_from=$((removed_from + 1))
        fi
    done
    
    if [ $removed_from -eq 0 ]; then
        echo "  ${YELLOW}○${NC} No Magic Scripts configurations found in shell files"
    else
        echo "  ${GREEN}✓${NC} Cleaned $removed_from shell configuration files"
    fi
}

verify_cleanup() {
    echo "${CYAN}Verifying cleanup...${NC}"
    
    local issues_found=0
    
    # Check install directory
    if [ -d "$INSTALL_DIR" ]; then
        echo "  ${RED}✗${NC} Install directory still exists: $INSTALL_DIR"
        issues_found=$((issues_found + 1))
    else
        echo "  ${GREEN}✓${NC} Install directory removed"
    fi
    
    # Check data directory  
    if [ -d "$DATA_DIR" ]; then
        echo "  ${RED}✗${NC} Data directory still exists: $DATA_DIR"
        issues_found=$((issues_found + 1))
    else
        echo "  ${GREEN}✓${NC} Data directory removed"
    fi
    
    # Check for ms command in PATH
    if command -v ms >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} 'ms' command still found in PATH"
        echo "    Location: $(command -v ms)"
        issues_found=$((issues_found + 1))
    else
        echo "  ${GREEN}✓${NC} 'ms' command removed from PATH"
    fi
    
    # Check for Magic Scripts man pages
    local man_pages_remaining=0
    for man_file in "$MAN_DIR"/ms*.1; do
        if [ -f "$man_file" ]; then
            man_pages_remaining=$((man_pages_remaining + 1))
        fi
    done
    
    if [ $man_pages_remaining -gt 0 ]; then
        echo "  ${RED}✗${NC} $man_pages_remaining Magic Scripts man pages still exist"
        issues_found=$((issues_found + 1))
    else
        echo "  ${GREEN}✓${NC} All Magic Scripts man pages removed"
    fi
    
    return $issues_found
}

show_completion() {
    local issues=$1
    
    echo ""
    if [ $issues -eq 0 ]; then
        echo "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
        echo "${GREEN}║              Cleanup Complete!                ║${NC}"
        echo "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
        echo ""
        echo "${GREEN}✅ Magic Scripts has been completely removed from your system.${NC}"
    else
        echo "${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
        echo "${YELLOW}║            Cleanup Incomplete                 ║${NC}"
        echo "${YELLOW}╚═══════════════════════════════════════════════╝${NC}"
        echo ""
        echo "${YELLOW}⚠️  $issues issues found during cleanup.${NC}"
        echo "${YELLOW}Some files or configurations may need manual removal.${NC}"
    fi
    
    echo ""
    echo "${CYAN}Next steps:${NC}"
    echo "  ${BLUE}•${NC} Restart your terminal or run: ${CYAN}exec \$SHELL${NC}"
    echo "  ${BLUE}•${NC} To reinstall Magic Scripts: ${CYAN}curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh${NC}"
    
    if [ $issues -gt 0 ]; then
        echo "  ${BLUE}•${NC} Check the issues above and remove any remaining files manually"
    fi
    
    echo ""
    echo "${BLUE}Shell configuration backups (if any) are saved with .magic-scripts-backup extension${NC}"
    echo ""
}

# Main execution
main() {
    show_header
    show_what_will_be_removed
    confirm_removal
    
    echo ""
    remove_executables
    remove_data_directory  
    remove_man_pages
    remove_shell_config
    
    echo ""
    verify_cleanup
    local issues=$?
    
    show_completion $issues
    
    exit $issues
}

# Handle help option
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_header
    echo "${CYAN}Magic Scripts Complete Cleanup Tool${NC}"
    echo ""
    echo "This script completely removes Magic Scripts from your system when"
    echo "the normal uninstall process doesn't work or Magic Scripts is corrupted."
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh${NC}"
    echo "  ${CYAN}./cleanup.sh${NC}"
    echo ""
    echo "${YELLOW}What it removes:${NC}"
    echo "  • All Magic Scripts executables (~/.local/bin/ms/)"
    echo "  • All data and configuration (~/.local/share/magicscripts/)"
    echo "  • Man pages (~/.local/share/man/man1/ms*.1)"
    echo "  • PATH modifications from shell configuration files"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "${RED}WARNING: This action cannot be undone!${NC}"
    echo ""
    exit 0
fi

# Run main function
main "$@"