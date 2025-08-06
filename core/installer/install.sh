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
TEMP_DIR="/tmp/magicscripts-$$"

# URLs
REPO_URL="https://github.com/nulLeeKH/magicscripts"
RAW_URL="https://raw.githubusercontent.com/nulLeeKH/magicscripts/main"

check_command() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

download_file() {
    local url="$1"
    local output="$2"
    
    if check_command curl; then
        curl -fsSL "$url" -o "$output"
    elif check_command wget; then
        wget -q "$url" -O "$output"
    else
        echo "${RED}Error: curl or wget is required${NC}"
        exit 1
    fi
}

update_shell_config() {
    local shell_config="$1"
    local path_line='export PATH="$HOME/.local/bin/ms:$PATH"'
    
    # Check if already exists
    if grep -q "export PATH.*\.local/bin/ms" "$shell_config" 2>/dev/null; then
        echo "${GREEN}PATH configuration already exists in $shell_config${NC}"
        return 1
    fi
    
    # Add configuration
    echo "" >> "$shell_config"
    echo "# Magic Scripts - added by installer" >> "$shell_config"
    echo "$path_line" >> "$shell_config"
    echo "${GREEN}Added PATH configuration to $shell_config${NC}"
    return 0
}

echo "========================================="
echo "           Magic Scripts v0.0.1         "
echo "       Developer Automation Tools       "
echo "========================================="
echo ""

# Check for existing installation
if [ -f "$HOME/.local/bin/ms/ms" ]; then
    echo "${YELLOW}Existing Magic Scripts installation detected.${NC}"
    echo "This will update the existing installation."
    echo ""
fi

echo "Creating installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$MAGIC_DIR"
mkdir -p "$TEMP_DIR"

echo "Downloading core system..."
mkdir -p "$MAGIC_DIR/core"
mkdir -p "$MAGIC_DIR/scripts"

printf "  Downloading config.sh... "
if download_file "$RAW_URL/core/config.sh" "$MAGIC_DIR/core/config.sh"; then
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

printf "  Downloading registry.sh... "
if download_file "$RAW_URL/core/registry.sh" "$MAGIC_DIR/core/registry.sh"; then
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

# Registry system will be initialized automatically by ms.sh
# No need to download registry files during installation

printf "  Downloading ms.sh... "
if download_file "$RAW_URL/core/ms.sh" "$MAGIC_DIR/scripts/ms.sh"; then
    chmod 755 "$MAGIC_DIR/scripts/ms.sh"
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

echo ""
echo "Installing Magic Scripts commands..."

printf "  Installing ms... "
cat > "$INSTALL_DIR/ms" << EOF
#!/bin/sh
MAGIC_SCRIPT_DIR="$MAGIC_DIR"
exec "\$MAGIC_SCRIPT_DIR/scripts/ms.sh" "\$@"
EOF
chmod 755 "$INSTALL_DIR/ms"

# Create metadata directory and file for ms command
mkdir -p "$MAGIC_DIR/installed"
cat > "$MAGIC_DIR/installed/ms.msmeta" << EOF
command=ms
version=0.0.1
registry_name=ms
registry_url=https://raw.githubusercontent.com/nulLeeKH/magicscripts/refs/heads/main/core/ms.msreg
checksum=a7f93a63
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
script_path=$MAGIC_DIR/scripts/ms.sh
EOF

printf "${GREEN}done${NC}\n"

echo ""
echo "Initializing registries..."
printf "  Updating ms registry... "
if "$INSTALL_DIR/ms" upgrade >/dev/null 2>&1; then
    printf "${GREEN}done${NC}\n"
else
    printf "${YELLOW}failed${NC}\n"
    echo "  ${YELLOW}Warning: Registry initialization failed. You can run 'ms upgrade' later.${NC}"
fi

echo ""

# Update shell configuration
PATH_UPDATED=false

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "${YELLOW}Updating shell configuration...${NC}"
    
    # Try to detect and update shell configuration files
    for config_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$config_file" ] || [ "$config_file" = "$HOME/.profile" ]; then
            if update_shell_config "$config_file"; then
                PATH_UPDATED=true
                SHELL_CONFIG="$config_file"
                break
            fi
        fi
    done
    
    if [ "$PATH_UPDATED" = false ]; then
        # Create .profile if no config file was found
        if update_shell_config "$HOME/.profile"; then
            PATH_UPDATED=true
            SHELL_CONFIG="$HOME/.profile"
        fi
    fi
else
    echo "${GREEN}$INSTALL_DIR is already in PATH${NC}"
fi

echo ""
echo "========================================="
echo "${GREEN}✅ Magic Scripts v0.0.1 installed!${NC}"
echo "========================================="
echo ""
echo "Installed core command:"
echo "  ${BLUE}ms${NC}           Magic Scripts main interface"
echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  ${CYAN}ms config list -r${NC}      # See available configuration keys"
echo "  ${CYAN}ms search${NC}              # Browse available commands"
echo "  ${CYAN}ms install -r ms${NC}       # Install all commands from ms registry"
echo "  ${CYAN}ms help${NC}                # Show detailed help"
echo ""

if [ "$PATH_UPDATED" = true ]; then
    echo "${YELLOW}IMPORTANT: To use commands immediately, run:${NC}"
    echo "  ${CYAN}source $SHELL_CONFIG${NC}"
    echo ""
    echo "Or restart your terminal."
else
    echo "${GREEN}All commands are ready to use!${NC}"
fi

echo ""
echo "Installation directory: ${CYAN}$INSTALL_DIR${NC}"
echo "Data directory: ${CYAN}$MAGIC_DIR${NC}"
echo "Repository: ${CYAN}$REPO_URL${NC}"