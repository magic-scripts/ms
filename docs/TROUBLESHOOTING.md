# Troubleshooting Guide

This guide helps you resolve common issues with Magic Scripts.

## Common Issues

### 1. `ms` Command Not Found

**Symptoms:**
```bash
$ ms --version
bash: ms: command not found
```

**Solutions:**

#### Check Installation
```bash
# Verify Magic Scripts is installed
ls -la ~/.local/bin/ms/
ls -la ~/.local/share/magicscripts/
```

#### Fix PATH
```bash
# Add to PATH temporarily
export PATH="$HOME/.local/bin/ms:$PATH"

# Add permanently to shell config
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.bashrc
# or for zsh:
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.zshrc

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

#### Reinstall
```bash
# Latest version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh

# Specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1
```

### 2. Magic Scripts Corrupted or Not Working

**Symptoms:**
- `ms` commands fail with errors
- Scripts don't execute properly
- Configuration is lost

**Solution: Emergency Cleanup**

```bash
# Complete system cleanup and reinstall
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh

# Then reinstall
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh

# Or install specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1
```

### 3. Permission Issues

**Symptoms:**
```bash
$ ms install gigen
Error: Permission denied
```

**Solutions:**

#### Check Directory Permissions
```bash
# Ensure directories exist and have correct permissions
mkdir -p ~/.local/bin ~/.local/share
chmod 755 ~/.local/bin ~/.local/share
```

#### Fix Installation Directory
```bash
# If Magic Scripts directory has wrong permissions
chmod -R 755 ~/.local/share/magicscripts
chmod +x ~/.local/bin/ms/*
```

### 4. Network Issues

**Symptoms:**
- Installation fails with connection errors
- Registry updates fail
- Commands can't be downloaded

**Solutions:**

#### Test Connectivity
```bash
# Test connection to Magic Scripts repository
curl -I https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh

# Alternative with wget
wget -q --spider https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh
```

#### Use Alternative Download Method
```bash
# If curl fails, try wget
wget -qO- https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

#### Corporate Firewall/Proxy
If you're behind a corporate firewall:
```bash
# Configure proxy (if needed)
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port

# Then retry installation
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh

# Or specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1
```

### 5. Checksum Mismatch Errors

**Symptoms:**
```bash
$ ms doctor
❌ command [version]: Checksum mismatch
```

**Solutions:**

#### For Development Versions
Development versions use `dev` checksum and should be safe:
```bash
# This is normal for dev versions
ℹ️ command [dev]: Dev version (checksum not verified)
```

#### For Release Versions
```bash
# Reinstall the specific command
ms reinstall command_name

# Or use doctor to auto-fix
ms doctor --fix
```

### 6. Registry Issues

**Symptoms:**
- `ms search` returns no results
- `ms install` can't find commands
- Registry updates fail

**Solutions:**

#### Update Registries
```bash
ms upgrade
```

#### Check Registry Status
```bash
ms reg list
ms doctor
```

#### Reset Registries
```bash
# Remove and re-add default registry
ms reg remove default
ms upgrade  # This will re-add the default registry
```

### 7. Configuration Issues

**Symptoms:**
- Settings are not saved
- Commands use wrong author information
- Configuration commands fail

**Solutions:**

#### Check Configuration
```bash
ms config list
```

#### Reset Configuration
```bash
# Remove config file and recreate
rm ~/.local/share/magicscripts/config
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"
```

#### Fix Configuration Permissions
```bash
chmod 644 ~/.local/share/magicscripts/config
```

## Advanced Troubleshooting

### Enable Debug Mode

For detailed debugging information:
```bash
# Run with debug output
sh -x ~/.local/share/magicscripts/scripts/ms.sh --version

# Or debug a specific command
sh -x ~/.local/bin/ms/gigen add node
```

### Check System Requirements

Magic Scripts requires:
- POSIX-compliant shell (bash, zsh, dash)
- curl or wget for downloads
- Basic Unix utilities (cut, grep, awk, etc.)

Test availability:
```bash
# Check shell
echo $SHELL

# Check required tools
command -v curl || command -v wget
command -v cut
command -v grep  
command -v awk
```

### Manual File Locations

If you need to manually inspect or fix files:

```bash
# Executables
~/.local/bin/ms/

# Main scripts and data
~/.local/share/magicscripts/
├── config                 # Configuration file
├── core/                  # Core system files
│   ├── config.sh         # Configuration management
│   └── registry.sh       # Registry system
├── scripts/              # Downloaded command scripts
├── installed/            # Installation metadata  
└── reg/                  # Registry cache

# Man pages
~/.local/share/man/man1/ms*.1
```

## Getting Help

If these solutions don't work:

1. **Check System Status**
   ```bash
   ms doctor
   ms status
   ```

2. **Complete Reset** (last resort)
   ```bash
   # Emergency cleanup
   curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh
   
   # Fresh installation
   curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
   
   # Or install specific version
   curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1
   ```

3. **Report Issues**
   - Check [GitHub Issues](https://github.com/magic-scripts/ms/issues)
   - Create a new issue with:
     - Your OS and shell version
     - Complete error messages  
     - Output of `ms doctor` (if available)
     - Steps to reproduce the problem

## Prevention Tips

- **Regular Updates**: Run `ms upgrade` regularly
- **Backup Config**: Keep a backup of important configurations
- **Monitor Disk Space**: Ensure adequate space in `~/.local/`
- **Shell Compatibility**: Use standard POSIX-compliant shells
- **Network Stability**: Ensure stable internet for installations

Remember: The cleanup script is your safety net when all else fails!