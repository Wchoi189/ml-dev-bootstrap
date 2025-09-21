# SSH Permissions Fix Utility

A standalone script to fix common SSH permission issues, especially useful for WSL users connecting to containers.

## Quick Start

```bash
# Fix permissions in your default SSH directory (~/.ssh)
./utils/fix-ssh-permissions.sh

# Fix permissions in a custom SSH directory
./utils/fix-ssh-permissions.sh /home/user/.ssh

# Show help
./utils/fix-ssh-permissions.sh --help

# Dry run (show what would be changed)
./utils/fix-ssh-permissions.sh --dry-run
```

## What It Fixes

- **SSH directory permissions** (700)
- **Private key permissions** (600)
- **Public key permissions** (644)
- **authorized_keys permissions** (600)
- **SSH config permissions** (600)
- **known_hosts permissions** (644)
- **WSL-specific permission issues**

## Integration

This script is automatically integrated into:

1. **SSH Module**: Runs automatically during SSH setup
2. **Interactive Menu**: Available as quick action "p) Fix SSH permissions"

## Common Issues Resolved

### WSL to Container Connections
```bash
# Before: Permission denied (publickey)
# After: Clean SSH connections
ssh container
```

### Permission Errors
```bash
# Before: Bad permissions for ~/.ssh/id_rsa
# After: Correct 600 permissions
ls -la ~/.ssh/id_rsa  # -rw------- 1 user user
```

### Multi-User Environments
```bash
# Fix permissions for specific user
sudo -u username ./utils/fix-ssh-permissions.sh
```

## Manual Usage

If you prefer to fix permissions manually:

```bash
# Fix directory permissions
chmod 700 ~/.ssh

# Fix private key permissions
chmod 600 ~/.ssh/id_*

# Fix public key permissions
chmod 644 ~/.ssh/*.pub

# Fix authorized_keys
chmod 600 ~/.ssh/authorized_keys
```