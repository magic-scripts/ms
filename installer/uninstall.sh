#!/bin/sh

set -e

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

echo "${RED}WARNING: This will completely remove Magic Scripts!${NC}"
echo ""
echo "This will remove:"
if [ -d "$INSTALL_DIR" ]; then
    echo "  - Installation directory: $INSTALL_DIR"
fi
if [ -d "$MAGIC_DIR" ]; then
    echo "  - Magic Scripts data (including config): $MAGIC_DIR"
fi
if [ -f "$HOME/.local/share/man/man1/ms.1" ]; then
    echo "  - Man page: ~/.local/share/man/man1/ms.1"
fi
echo "  - PATH and MANPATH modifications from shell configuration files"
echo ""
printf "Are you sure? Type 'yes' to continue: "
read reply < /dev/tty

case "$reply" in
    yes)
        echo ""
        echo "${YELLOW}Removing Magic Scripts...${NC}"
        ;;
    *)
        echo "Uninstall cancelled."
        exit 1
        ;;
esac

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "  ${GREEN}Removed${NC}: Installation directory ($INSTALL_DIR)"
else
    echo "  ${YELLOW}Not found${NC}: Installation directory"
fi

# Remove Magic Scripts data directory
if [ -d "$MAGIC_DIR" ]; then
    rm -rf "$MAGIC_DIR"
    echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
else
    echo "  ${YELLOW}Not found${NC}: Magic Scripts data directory"
fi

# Remove man page
MAN_FILE="$HOME/.local/share/man/man1/ms.1"
if [ -f "$MAN_FILE" ]; then
    rm -f "$MAN_FILE"
    echo "  ${GREEN}Removed${NC}: Man page ($MAN_FILE)"
else
    echo "  ${YELLOW}Not found${NC}: Man page"
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
echo "${GREEN}✅ Magic Scripts v0.0.1 uninstalled!${NC}"
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