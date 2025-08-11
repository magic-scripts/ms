#!/bin/sh

set -e

VERSION="0.0.1"

# Cleanup function for safe exit
cleanup_uninstall() {
    # Clean up any temporary files created during uninstall
    # Currently no temp files are created, but this is for future-proofing
    true
}

# Set trap for cleanup on exit/interrupt
trap cleanup_uninstall EXIT INT TERM

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin/ms"
MAGIC_DIR="$HOME/.local/share/magicscripts"

remove_from_shell_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Check if the PATH line exists
    if grep -q "export PATH.*\.local/bin/ms" "$config_file"; then
        # Create temp file without the Magic Scripts lines
        grep -v "# Magic Scripts - added by installer" "$config_file" | \
        grep -v "export PATH.*\.local/bin/ms" | \
        grep -v "export MANPATH.*\.local/share/man" > "$config_file.tmp"
        
        # Remove empty lines that might be left
        awk 'BEGIN{blank=0} /^$/{blank++} !/^$/{for(i=0;i<blank;i++)print ""; blank=0; print}' "$config_file.tmp" > "$config_file.tmp2"
        mv "$config_file.tmp2" "$config_file"
        rm -f "$config_file.tmp"
        
        echo "  ${GREEN}Removed${NC}: PATH and MANPATH configuration from $config_file"
        return 0
    fi
    
    return 1
}

echo "========================================="
echo "     Magic Scripts Complete Uninstaller "
echo "=========================================="
echo ""

# Check if Magic Scripts is installed
if [ ! -f "$INSTALL_DIR/ms" ] && [ ! -d "$INSTALL_DIR" ] && [ ! -d "$MAGIC_DIR" ]; then
    echo "${YELLOW}Magic Scripts doesn't appear to be installed.${NC}"
    echo ""
    echo "If you installed it in a different location, you may need to remove it manually."
    exit 0
fi

# List installed Magic Scripts commands
INSTALLED_COMMANDS=""
INSTALLED_COUNT=0
if [ -d "$INSTALL_DIR" ]; then
    for cmd_file in "$INSTALL_DIR"/*; do
        # Check if glob actually expanded (not literal *)
        [ -e "$cmd_file" ] || continue
        if [ -x "$cmd_file" ]; then
            cmd=$(basename "$cmd_file")
            INSTALLED_COMMANDS="$INSTALLED_COMMANDS $cmd"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi
    done
fi

echo "${RED}WARNING: This will completely remove Magic Scripts!${NC}"
echo ""
echo "This will remove:"
echo "  ${CYAN}Core System:${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo "    - Installation directory: $INSTALL_DIR"
fi
if [ -d "$MAGIC_DIR" ]; then
    echo "    - Magic Scripts data directory: $MAGIC_DIR"
    echo "      (configuration, registries, core libraries)"
fi
echo "    - PATH and MANPATH modifications from shell configs"
echo ""

if [ "$INSTALLED_COUNT" -gt 1 ]; then
    echo "  ${YELLOW}Other installed commands ($((INSTALLED_COUNT - 1))):${NC}"
    for cmd in $INSTALLED_COMMANDS; do
        if [ "$cmd" != "ms" ]; then
            echo "    - $cmd"
        fi
    done
    echo ""
    echo "  ${YELLOW}Note: You can keep these by answering 'no' below${NC}"
    echo ""
fi

printf "${RED}Remove Magic Scripts core only?${NC} [yes/all/no]: "
read reply < /dev/tty

REMOVE_ALL_COMMANDS=false

case "$reply" in
    yes|YES)
        echo ""
        echo "${YELLOW}Removing Magic Scripts core...${NC}"
        REMOVE_ALL_COMMANDS=false
        ;;
    all|ALL)
        echo ""
        echo "${YELLOW}Removing Magic Scripts and all installed commands...${NC}"
        REMOVE_ALL_COMMANDS=true
        ;;
    *)
        echo "Uninstall cancelled."
        exit 1
        ;;
esac

# Remove ms executable first
if [ -f "$INSTALL_DIR/ms" ]; then
    rm -f "$INSTALL_DIR/ms"
    echo "  ${GREEN}Removed${NC}: ms command"
fi

# Handle other commands based on user choice
if [ "$REMOVE_ALL_COMMANDS" = true ]; then
    # Remove entire installation directory
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "  ${GREEN}Removed${NC}: Installation directory with all commands"
    fi
else
    # Keep other commands but remove ms-related items
    if [ "$INSTALLED_COUNT" -gt 1 ]; then
        echo "  ${CYAN}Keeping other installed commands${NC}"
        # Remove ms directory if empty or only has other commands
        if [ -d "$INSTALL_DIR" ]; then
            # Check if directory is now empty
            remaining=$(ls -1 "$INSTALL_DIR" 2>/dev/null | wc -l)
            if [ "$remaining" -eq 0 ]; then
                rmdir "$INSTALL_DIR" 2>/dev/null || true
                echo "  ${GREEN}Removed${NC}: Empty installation directory"
            fi
        fi
    else
        # No other commands, remove directory
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
            echo "  ${GREEN}Removed${NC}: Installation directory (was empty)"
        fi
    fi
fi

# Remove Magic Scripts data directory (selectively based on user choice)
if [ "$REMOVE_ALL_COMMANDS" = true ]; then
    # Remove entire data directory
    if [ -d "$MAGIC_DIR" ]; then
        rm -rf "$MAGIC_DIR"
        echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
    else
        echo "  ${YELLOW}Not found${NC}: Magic Scripts data directory"
    fi
else
    # Remove only ms-related core files, keep other command data
    if [ -d "$MAGIC_DIR" ]; then
        # Remove core directory (contains config.sh, registry.sh)
        if [ -d "$MAGIC_DIR/core" ]; then
            rm -rf "$MAGIC_DIR/core"
            echo "  ${GREEN}Removed${NC}: Core libraries"
        fi
        
        # Remove ms script
        if [ -f "$MAGIC_DIR/scripts/ms.sh" ]; then
            rm -f "$MAGIC_DIR/scripts/ms.sh"
            echo "  ${GREEN}Removed${NC}: ms.sh script"
        fi
        
        # Remove ms metadata
        if [ -f "$MAGIC_DIR/installed/ms.msmeta" ]; then
            rm -f "$MAGIC_DIR/installed/ms.msmeta"
            echo "  ${GREEN}Removed${NC}: ms metadata"
        fi
        
        # Remove registry data
        if [ -d "$MAGIC_DIR/reg" ]; then
            rm -rf "$MAGIC_DIR/reg"
            echo "  ${GREEN}Removed${NC}: Registry cache"
        fi
        
        # Remove config file
        if [ -f "$MAGIC_DIR/config" ]; then
            rm -f "$MAGIC_DIR/config"
            echo "  ${GREEN}Removed${NC}: Configuration file"
        fi
        
        # Check if scripts directory is empty and remove if so
        if [ -d "$MAGIC_DIR/scripts" ]; then
            if [ -z "$(ls -A "$MAGIC_DIR/scripts" 2>/dev/null)" ]; then
                rmdir "$MAGIC_DIR/scripts"
            fi
        fi
        
        # Check if installed directory is empty and remove if so
        if [ -d "$MAGIC_DIR/installed" ]; then
            if [ -z "$(ls -A "$MAGIC_DIR/installed" 2>/dev/null)" ]; then
                rmdir "$MAGIC_DIR/installed"
            fi
        fi
        
        # Check if entire MAGIC_DIR is empty and remove if so
        if [ -z "$(ls -A "$MAGIC_DIR" 2>/dev/null)" ]; then
            rmdir "$MAGIC_DIR"
            echo "  ${GREEN}Removed${NC}: Empty data directory"
        else
            echo "  ${CYAN}Kept${NC}: Data for other installed commands"
        fi
    fi
fi

# Remove man pages
MAN_DIR="$HOME/.local/share/man/man1"
if [ "$REMOVE_ALL_COMMANDS" = true ]; then
    # Remove all Magic Scripts man pages
    removed_man_count=0
    for man_file in "$MAN_DIR"/ms*.1; do
        if [ -f "$man_file" ]; then
            rm -f "$man_file"
            removed_man_count=$((removed_man_count + 1))
        fi
    done
    if [ $removed_man_count -gt 0 ]; then
        echo "  ${GREEN}Removed${NC}: $removed_man_count man pages"
    fi
else
    # Remove only ms man page
    if [ -f "$MAN_DIR/ms.1" ]; then
        rm -f "$MAN_DIR/ms.1"
        echo "  ${GREEN}Removed${NC}: ms man page"
    fi
fi

# Configuration is now part of MAGIC_DIR, removed with data directory above

# Remove PATH modifications from shell config files
echo ""
echo "Removing PATH modifications from shell configuration..."

PATH_REMOVED=false
for config_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if remove_from_shell_config "$config_file"; then
        PATH_REMOVED=true
    fi
done

if [ "$PATH_REMOVED" = false ]; then
    echo "  ${YELLOW}No PATH modifications found${NC} in shell configuration files"
fi

echo ""
echo "========================================="
echo "${GREEN}✅ Magic Scripts v$VERSION uninstalled!${NC}"
echo "========================================="
echo ""

if [ "$PATH_REMOVED" = true ]; then
    echo "${YELLOW}IMPORTANT: Restart your terminal or run:${NC}"
    echo "  ${CYAN}source ~/.zshrc${NC}  # or ~/.bashrc, ~/.profile"
    echo ""
    echo "to apply PATH changes."
    echo ""
fi

echo "Thank you for using Magic Scripts!"
echo ""
echo "If you want to reinstall in the future:"
echo "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh${NC}"
echo "Or if you have Magic Scripts still partially installed:"
echo "  ${CYAN}ms upgrade && ms install ms${NC}"