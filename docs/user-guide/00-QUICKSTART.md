# Quickstart — Using Magic Scripts

Get up and running with Magic Scripts in under 5 minutes.

---

## 1. Install ms

```sh
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

After installation, reload your shell:

```sh
source ~/.zshrc   # zsh
source ~/.bashrc  # bash
```

Verify:

```sh
ms --version
```

---

## 2. Browse available commands

```sh
ms search           # list all commands
ms search port      # search by keyword
ms info portcheck   # view details for a specific command
```

---

## 3. Install a command

```sh
ms install portcheck
```

Once installed, the command is immediately available:

```sh
portcheck --version
portcheck --help
```

---

## 4. Try portcheck

**Show which process is using a port:**

```sh
portcheck 3000
```

Example output:
```
Port 3000 is in use:

COMMAND      PID      USER     FD     ADDRESS
node         12345    alice    23u    *:3000
```

**List all listening ports:**

```sh
portcheck --list
```

**Kill the process using a port (with confirmation):**

```sh
portcheck 3000 --kill
```

**Force kill immediately:**

```sh
portcheck 3000 -k
```

---

## 5. Manage installed commands

```sh
ms status              # list installed commands and versions
ms update portcheck    # update a specific command
ms update              # update all commands
ms uninstall portcheck # remove a command
```

---

## Next steps

- [02-COMMANDS.md](02-COMMANDS.md) — full ms command reference
- [03-CONFIGURATION.md](03-CONFIGURATION.md) — per-command configuration
- [04-TROUBLESHOOTING.md](04-TROUBLESHOOTING.md) — troubleshooting guide
