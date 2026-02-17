# Troubleshooting Guide

This guide covers common issues with Magic Scripts (`ms`) and how to resolve them. Work through the relevant section for your problem, or jump to [Getting Help](#getting-help) if you need immediate assistance.

---

## Table of Contents

1. [Command Not Found](#1-command-not-found)
2. [Corrupted Installation](#2-corrupted-installation)
3. [Permission Issues](#3-permission-issues)
4. [Network Issues](#4-network-issues)
5. [Checksum Mismatch](#5-checksum-mismatch)
6. [Registry Issues](#6-registry-issues)
7. [Configuration Issues](#7-configuration-issues)
8. [Advanced Troubleshooting](#8-advanced-troubleshooting)
9. [Getting Help](#9-getting-help)

---

## 1. Command Not Found

**Symptom:** Running `ms` returns `command not found` or similar.

### Check Your PATH

Verify that the Magic Scripts binary directory is in your PATH:

```sh
echo "$PATH" | tr ':' '\n' | grep -i magic
```

The expected path is `$HOME/.local/bin/ms`. If it is missing, add it to your shell profile.

### Fix Your PATH

Add the following line to your shell configuration file (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```sh
export PATH="$HOME/.local/bin/ms:$PATH"
```

Then reload your shell:

```sh
source ~/.bashrc    # or ~/.zshrc, ~/.profile
```

### Verify the Binary Exists

```sh
ls -la "$HOME/.local/bin/ms/ms"
```

If the file does not exist, the installation may be incomplete or corrupted. See [Corrupted Installation](#2-corrupted-installation) or reinstall:

```sh
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

---

## 2. Corrupted Installation

**Symptom:** `ms` commands behave unexpectedly, produce errors about missing files, or fail to start.

### Emergency Cleanup

If your installation is in a bad state, run the official cleanup script:

```sh
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh
```

This removes all Magic Scripts files and allows you to start fresh. After cleanup, reinstall:

```sh
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

### What Gets Removed

The cleanup script removes:

- `$HOME/.local/bin/ms/` -- command wrappers
- `$HOME/.local/share/magicscripts/` -- installed scripts, registry cache, and metadata
- Any related shell profile modifications

Your project-level `.msconfig` files are **not** removed.

---

## 3. Permission Issues

**Symptom:** Errors like `Permission denied` when running `ms` commands, installing scripts, or writing configuration.

### Fix Directory Permissions

Ensure the Magic Scripts directories have correct ownership and permissions:

```sh
chmod -R u+rwX "$HOME/.local/bin/ms"
chmod -R u+rwX "$HOME/.local/share/magicscripts"
```

### Check File Ownership

If you installed with `sudo` by mistake, files may be owned by root:

```sh
ls -la "$HOME/.local/bin/ms/"
ls -la "$HOME/.local/share/magicscripts/"
```

Fix ownership if needed:

```sh
chown -R "$(whoami)" "$HOME/.local/bin/ms"
chown -R "$(whoami)" "$HOME/.local/share/magicscripts"
```

### Avoid Running as Root

Never run `ms` with `sudo`. Magic Scripts is designed to install into user-level directories and does not require elevated privileges.

---

## 4. Network Issues

**Symptom:** Commands like `ms install`, `ms upgrade`, or `ms search` fail with download or connection errors.

### Test Connectivity

Check that you can reach the registry host:

```sh
curl -fsSL https://raw.githubusercontent.com/ -o /dev/null && echo "OK" || echo "FAILED"
```

### Common Causes

- **Corporate firewall or proxy** -- Configure your proxy environment variables:

  ```sh
  export HTTP_PROXY="http://proxy.example.com:8080"
  export HTTPS_PROXY="http://proxy.example.com:8080"
  ```

- **DNS resolution failure** -- Try using a known DNS resolver:

  ```sh
  nslookup raw.githubusercontent.com
  ```

- **TLS/SSL issues** -- Ensure your system certificates are up to date. On macOS, update via System Preferences. On Linux, update the `ca-certificates` package.

### Verify Registry URLs

Check that your configured registries point to valid URLs:

```sh
ms reg list
```

All registry URLs must use HTTPS. HTTP URLs are rejected by design.

---

## 5. Checksum Mismatch

**Symptom:** Installation fails with a checksum verification error.

### Development Versions

If you are working with a local development version (using `MAGIC_SCRIPT_DIR`), checksum mismatches are **expected and normal**. The checksums in `.msver` files correspond to release builds, not local modifications.

### Release Versions

For release versions, a checksum mismatch indicates the downloaded file does not match the expected content. This could mean:

- A corrupted download (network issue)
- A tampered file (security concern)
- An outdated registry cache pointing to old checksums

**To resolve:**

1. Refresh the registry cache:

   ```sh
   ms upgrade
   ```

2. Try the installation again:

   ```sh
   ms install pgadduser
   ```

3. If the problem persists, verify the checksum manually:

   ```sh
   mschecksum checksum scripts/pgadduser.sh
   ```

   Compare the output against the value in the corresponding `.msver` file.

---

## 6. Registry Issues

**Symptom:** Commands are not found in search results, registries fail to update, or duplicate entries appear.

### Refresh Registries

Update all registry caches:

```sh
ms upgrade
```

### List Configured Registries

View your current registry configuration:

```sh
ms reg list
```

Verify that the URLs are correct and reachable.

### Reset Registries to Default

If your registry configuration is damaged, remove the cached registry data and re-initialize:

```sh
rm -rf "$HOME/.local/share/magicscripts/reg/"
ms upgrade
```

This clears all cached `.msreg`, `.mspack`, and `.msver` files and re-downloads them from the configured sources.

### Add or Remove a Registry

```sh
ms reg add <name> <url>
ms reg remove <name>
```

Registry URLs must use HTTPS.

---

## 7. Configuration Issues

**Symptom:** Commands use unexpected settings, configuration changes do not take effect, or config commands fail.

### View Current Configuration

List all active configuration values and their sources:

```sh
ms config list
```

Configuration follows a three-tier precedence:

1. **Local project config** (`.msconfig` in the current directory) -- highest priority
2. **Global user config** (`$HOME/.local/share/magicscripts/config`)
3. **Registry defaults** (declared in `.mspack` files) -- lowest priority

### Reset Configuration

To reset global configuration to defaults:

```sh
rm "$HOME/.local/share/magicscripts/config"
```

To reset a project-level override, remove or edit the `.msconfig` file in the project directory.

### Fix Config File Permissions

If config commands fail with permission errors:

```sh
chmod 644 "$HOME/.local/share/magicscripts/config"
```

For project-level config:

```sh
chmod 644 .msconfig
```

---

## 8. Advanced Troubleshooting

### Debug Mode

Run any `ms` command with shell tracing to see exactly what is happening:

```sh
sh -x "$HOME/.local/bin/ms/ms" status
```

Or if using a development checkout:

```sh
sh -x ./ms/scripts/ms.sh status
```

This prints every command as it executes, which is invaluable for diagnosing unexpected behavior.

### System Requirements

Magic Scripts requires:

- A POSIX-compatible shell (`/bin/sh`)
- `curl` or `wget` for downloads
- `sha256sum` or `shasum` for checksum verification
- Standard UNIX utilities: `grep`, `sed`, `awk`, `tr`, `cut`, `mkdir`, `chmod`

Verify key dependencies:

```sh
command -v curl && echo "curl: OK" || echo "curl: MISSING"
command -v sha256sum || command -v shasum && echo "sha256: OK" || echo "sha256: MISSING"
```

### File Locations

| Purpose | Path |
|---|---|
| Command wrappers | `$HOME/.local/bin/ms/` |
| Installed scripts | `$HOME/.local/share/magicscripts/scripts/` |
| Installation metadata | `$HOME/.local/share/magicscripts/installed/` |
| Registry cache | `$HOME/.local/share/magicscripts/reg/` |
| Global config | `$HOME/.local/share/magicscripts/config` |
| Project config | `.msconfig` (in project root) |

### Environment Variables

| Variable | Purpose |
|---|---|
| `MAGIC_SCRIPT_DIR` | Points to a local source directory for development mode |
| `MS_SCRIPT_ID` | Set by each command to declare its identity for config access |

---

## 9. Getting Help

### Built-in Diagnostics

Run the doctor command to check your installation health:

```sh
ms doctor
```

This checks PATH configuration, directory permissions, registry connectivity, and installed command integrity.

View the status of all installed commands:

```sh
ms status
```

### Complete Reset

If all else fails, perform a full reset:

```sh
# 1. Remove everything
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh

# 2. Reinstall
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh

# 3. Verify
ms doctor
```

### Report an Issue

If you cannot resolve your problem, open an issue on the GitHub repository:

1. Run `ms doctor` and `ms status` and copy the output.
2. Note your operating system and shell version (`uname -a`, `$SHELL --version`).
3. Describe the steps to reproduce the issue.
4. Open an issue at the Magic Scripts GitHub repository with the above information.

Providing this detail helps maintainers diagnose and fix the problem quickly.
