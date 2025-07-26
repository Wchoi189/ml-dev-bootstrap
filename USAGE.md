
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
| `--verbose` | Enable detailed, verbose logging for debugging. | `sudo ./setup.sh --verbose system` |
| `--update` | Run the update function within each module. | `sudo ./setup.sh --update` |
| `--backup` | Create a backup of key configuration files. | `sudo ./setup.sh --backup` |

-----

## Module Details

  - **`system`**: Installs essential development packages and build tools (`git`, `vim`, `gcc`, etc.) and updates the system.
  - **`locale`**: Configures system-wide locales, with a focus on `en_US.UTF-8` and `ko_KR.UTF-8`. Installs required fonts.
  - **`user`**: Creates a dedicated development user and group with appropriate permissions and home directory structure.
  - **`conda`**: Detects and updates a Conda installation, configures channels, and sets user permissions.
  - **`git`**: Configures global git settings, including user info, default branch name, and useful aliases.
  - **`prompt`**: Sets up a modern, informative shell prompt that displays the current git branch and conda environment.

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