
# Usage Guide

This guide provides detailed information on how to use the `ml-dev-bootstrap` utility, including advanced options, module details, and configuration.

---

## Basic Commands

These are the most common commands for setting up your environment.

```bash
# Run all setup modules using the interactive menu
sudo ./setup.sh --menu

# Run all modules non-interactively with a progress bar
sudo ./setup.sh --all --progress

# Run only specific modules
sudo ./setup.sh system git locale
```

-----

## Advanced Options

Fine-tune the script's behavior with these flags.

| Flag | Description | Example |
| :--- | :--- | :--- |
| `--dry-run` | Preview all changes without executing them. | `sudo ./setup.sh --all --dry-run` |
| `--diagnose` | Run diagnostic checks on all modules. | `sudo ./setup.sh --diagnose` |
| `--list` | Show a list of all available modules. | `./setup.sh --list` |
| `--switch-user` | Switch to the development user for continued setup. | `sudo ./setup.sh --switch-user` |
| `--verbose` | Enable detailed, verbose logging for debugging. | `sudo ./setup.sh --verbose system` |
| `--update` | Run the update function within each module. | `sudo ./setup.sh --update` |
| `--backup` | Create a backup of key configuration files. | `sudo ./setup.sh --backup` |

-----

## Module Details

  - **`system`**: Installs essential development packages and build tools (`git`, `vim`, `gcc`, etc.) and updates the system.
  - **`locale`**: Configures system-wide locales, with a focus on `en_US.UTF-8` and `ko_KR.UTF-8`. Installs required fonts.
  - **`user`**: Creates a dedicated development user and group with appropriate permissions and home directory structure.
  - **`sources`**: Configures APT sources to use regional mirrors for faster package downloads (Kakao, Naver, Daum, etc.).
  - **`conda`**: Detects and updates a Conda (Micromamba) installation, configures channels, and sets user permissions.
  - **`envmgr`**: Interactive installer for conda/micromamba, pyenv, poetry, and pipenv with multi-user dev-group permissions.
  - **`git`**: Configures global git settings, including user info, default branch name, and useful aliases.
  - **`prompt`**: Sets up a modern, informative shell prompt that displays the current git branch and conda environment.

-----

## User Workflow

The script is designed to handle user creation and permission delegation properly:

### Step 1: Run Initial Setup as Root
```bash
sudo ./setup.sh --all  # Or run specific modules
```

### Step 2: Switch to Development User
After creating the user, switch to the development user account:
```bash
sudo ./setup.sh --switch-user
# Or manually: su - dev-user
```

### Step 3: Continue Setup as User
Once switched to the development user, continue with user-specific installations:
```bash
# Use the convenient symlink in your home directory
cd ~/setup && ./setup.sh --menu

# Or navigate to the main location
cd /opt/ml-dev-bootstrap && ./setup.sh --menu
```

### File Locations
The setup files are strategically located for optimal access:
- **Main Location**: `/opt/ml-dev-bootstrap` (optimal permissions)
- **User Symlink**: `~/setup` (convenient access)
- **Compatibility**: `/root/ml-dev-bootstrap` (symlink for existing scripts)

### Permission System
- **Group-based Access**: All setup files owned by `root:dev` group
- **Setgid Directories**: New files inherit dev group ownership
- **Multi-user Support**: Development users can read/write setup files
- **Flexible Root Requirements**: System operations require root, user operations can run as user

-----

## Configuration

You can configure the script in two primary ways:

#### 1\. Edit the Configuration File

The simplest method is to edit the `config/defaults.conf` file directly.

```bash
# Example snippet from config/defaults.conf

# User Configuration
USERNAME=devuser
USER_GROUP=dev

# Git Configuration
GIT_USER_NAME="Developer"
GIT_USER_EMAIL="dev@example.com"
```

#### 2\. Use Environment Variables

For temporary changes or use in CI/CD environments, you can override settings with environment variables. You must use `sudo -E` to pass the variables to the root environment.

```bash
# Example of overriding the git user and running the git module
export GIT_USER_NAME="Jane Doe"
export GIT_USER_EMAIL="jane.doe@example.com"
sudo -E ./setup.sh git
```

-----

## Examples

#### Full Environment Setup

Set a custom user and git identity, then run the entire setup.

```bash
export USERNAME=jdoe
export GIT_USER_NAME="Jane Doe"
export GIT_USER_EMAIL="jane.doe@example.com"
sudo -E ./setup.sh --all --progress
```

#### Dockerfile Integration

Use the script to provision a development container.

```dockerfile
FROM ubuntu:22.04

COPY ml-dev-bootstrap /opt/ml-dev-bootstrap
WORKDIR /opt/ml-dev-bootstrap

# Run the setup non-interactively
RUN ./setup.sh --all

# Switch to the new user
USER devuser
WORKDIR /home/devuser
CMD ["/bin/bash"]
```

-----

## Environment Managers: Selection and Permissions

Launch from the menu with option `e`, then select one or more managers:

```
1) conda
2) micromamba
3) pyenv
4) poetry
5) pipenv
```

Behavior and locations:
- Poetry: system-wide to `/opt/pypoetry` (default) with dev-group permissions; shim at `/usr/local/bin/poetry`.
- Pyenv: installed for the configured user (USERNAME) or root; dev-group permissions are applied; shim at `/usr/local/bin/pyenv`.
- Pipenv: installed per user with dev-group permissions; optional shim at `/usr/local/bin/pipenv`.

PATH is ensured across sessions via `/etc/profile.d/ml-dev-tools.sh` which adds `/usr/local/bin`, `/opt/pypoetry/bin`, and `$HOME/.local/bin`.

-----

## Troubleshooting

### poetry: command not found (127)

If `poetry` was just installed and the shell still returns 127, refresh your shell:

```bash
hash -r
exec $SHELL -l
poetry --version
```

Check that the shim exists and points to the right target:

```bash
readlink -f /usr/local/bin/poetry
ls -l /opt/pypoetry/bin
```

### Permission denied or missing access for other users

Verify the dev group exists and directories are group-writable with setgid:

```bash
getent group dev
ls -ld /opt/pypoetry /opt/pypoetry/bin /opt/pypoetry/venv
```