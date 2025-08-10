# Troubleshooting Guide

Common issues and their solutions for Magic Scripts.

## Installation Issues

### Command not found after installation

**Symptoms:**
```bash
$ ms
bash: ms: command not found
```

**Solutions:**
1. Add Magic Scripts to your PATH:
```bash
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For Zsh users
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For Fish users
fish_add_path ~/.local/bin/ms
```

2. Verify installation:
```bash
ls -la ~/.local/bin/ms/
```

### Permission denied errors

**Symptoms:**
```bash
$ ms status
bash: ~/.local/bin/ms/ms: Permission denied
```

**Solutions:**
```bash
# Fix permissions
chmod +x ~/.local/bin/ms/ms
chmod +x ~/.local/bin/ms/*
```

### Installation script fails

**Symptoms:**
```bash
curl: (22) The requested URL returned error: 404 Not Found
```

**Solutions:**
1. Check internet connection
2. Try alternative installation method:
```bash
wget -qO- https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh
```
3. Manual installation:
```bash
git clone https://github.com/magic-scripts/ms.git
cd ms
./installer/install.sh
```

## Configuration Issues

### Configuration not working

**Symptoms:**
- Config values not being used by commands
- `ms config list` shows empty or wrong values

**Solutions:**
1. Check config file location:
```bash
ls -la ~/.local/share/magicscripts/config
```

2. Verify config registry:
```bash
ms config list -r
```

3. Reset configuration:
```bash
# Backup existing config
cp ~/.local/share/magicscripts/config ~/.local/share/magicscripts/config.backup

# Regenerate config registry
ms upgrade
```

### Command can't access config

**Symptoms:**
```bash
Error: Configuration key 'AUTHOR_NAME' is not registered for this command
```

**Solutions:**
1. Check if key is registered:
```bash
ms config list -r | grep AUTHOR_NAME
```

2. Update registries:
```bash
ms upgrade
```

3. Install/reinstall the command:
```bash
ms install mycommand --force
```

## Registry Issues

### Registry update failures

**Symptoms:**
```bash
$ ms upgrade
Error: Failed to download registry from https://...
```

**Solutions:**
1. Check internet connectivity
2. Verify registry URL:
```bash
ms reg list
```

3. Remove and re-add problematic registry:
```bash
ms reg remove problematic-registry
ms reg add problematic-registry https://correct-url.com/registry.msreg
```

4. Manual registry update:
```bash
# Clear cache
rm -rf ~/.local/share/magicscripts/reg/*.msreg
ms upgrade
```

### Registry not found

**Symptoms:**
```bash
Error: Registry 'myregistry' not found or empty
```

**Solutions:**
1. List available registries:
```bash
ms reg list
```

2. Add the missing registry:
```bash
ms reg add myregistry https://example.com/registry.msreg
```

3. Use correct registry name:
```bash
ms install -r default mycommand
```

## Command Installation Issues

### Download failures

**Symptoms:**
```bash
Error: Failed to download script from https://...
```

**Solutions:**
1. Check internet connection
2. Verify URL is accessible:
```bash
curl -I https://problematic-url.com/script.sh
```

3. Try installation with verbose output:
```bash
ms install mycommand --verbose
```

### Checksum verification failures

**Symptoms:**
```bash
Error: Checksum mismatch for mycommand
Expected: abc123...
Got: def456...
```

**Solutions:**
1. Update registries to get latest checksums:
```bash
ms upgrade
```

2. Skip checksum verification (not recommended):
```bash
# Only for development/testing
export MS_SKIP_CHECKSUM=1
ms install mycommand
unset MS_SKIP_CHECKSUM
```

3. Report issue to command maintainer

### Script execution fails

**Symptoms:**
```bash
$ mycommand
/bin/sh: /path/to/script: No such file or directory
```

**Solutions:**
1. Check if script file exists:
```bash
ls -la ~/.local/share/magicscripts/scripts/mycommand.sh
```

2. Reinstall the command:
```bash
ms uninstall mycommand
ms install mycommand
```

3. Check wrapper script:
```bash
cat ~/.local/bin/ms/mycommand
```

## System Diagnostic Tools

### Built-in Diagnostics

```bash
# Run comprehensive system check
ms doctor

# Check installation status
ms status

# Verify specific command
ms versions mycommand
```

### Manual Diagnostics

```bash
# Check directory structure
ls -la ~/.local/bin/ms/
ls -la ~/.local/share/magicscripts/

# Check PATH configuration
echo $PATH | grep -o '\.local/bin/ms'

# Check registry status
ms reg list

# Check configuration
ms config list
```

## File Permissions Issues

### Scripts not executable

**Solutions:**
```bash
# Fix Magic Scripts permissions
find ~/.local/bin/ms/ -name "*" -exec chmod +x {} \;
find ~/.local/share/magicscripts/scripts/ -name "*.sh" -exec chmod +x {} \;
```

### Configuration file permissions

**Solutions:**
```bash
# Fix config file permissions
chmod 644 ~/.local/share/magicscripts/config
chmod 755 ~/.local/share/magicscripts/
```

## Network Issues

### HTTPS certificate problems

**Symptoms:**
```bash
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

**Solutions:**
1. Update certificates:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ca-certificates

# macOS
brew install ca-certificates

# CentOS/RHEL
sudo yum update ca-certificates
```

2. Use alternative download method:
```bash
wget --no-check-certificate -qO- https://...
```

### Corporate proxy/firewall

**Solutions:**
1. Configure proxy:
```bash
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080
```

2. Use internal mirror if available
3. Request firewall whitelist for Magic Scripts domains

## Advanced Troubleshooting

### Enable debug mode

```bash
# Enable verbose output
export MS_DEBUG=1
ms install mycommand
unset MS_DEBUG
```

### Clean reinstallation

```bash
# Complete removal and reinstall
~/.local/bin/ms/ms uninstall --all
rm -rf ~/.local/share/magicscripts/
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh
```

### Check system compatibility

```bash
# Verify shell compatibility
echo $SHELL

# Check required tools
command -v curl || echo "curl missing"
command -v wget || echo "wget missing" 
command -v sha256sum || echo "sha256sum missing"
```

## Getting Help

If you continue to experience issues:

1. **Check system status:**
   ```bash
   ms doctor
   ms status
   ```

2. **Search existing issues:**
   Visit the [GitHub Issues](https://github.com/magic-scripts/ms/issues) page

3. **Create a bug report:**
   Include output from `ms doctor` and `ms status` commands

4. **Community support:**
   Join discussions in the project repository