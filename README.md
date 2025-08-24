# ml-dev-bootstrap

[![Version](https://img.shields.io/badge/version-0.1.0--beta-blue)](https://github.com/Wchoi189/ml-dev-bootstrap/releases)

A modular setup utility for bootstrapping a development environment on a fresh Ubuntu system. It configures everything from system tools and users to conda, git, and shell prompts.

## Key Features

-   ✅ **Modular Architecture**: Run the whole setup or pick just the components you need.
-   ✅ **User & System Config**: Sets up users, groups, locales, and essential development tools.
-   ✅ **Conda & Git Ready**: Configures conda environments and git settings with useful aliases.
-   ✅ **Beautiful Prompts**: Includes several informative shell prompt styles.
-   ✅ **Dry-run Mode**: Preview all changes before they are made.
-   ✅ **Interactive Menu**: A user-friendly menu to guide you through the setup.
-   ✅ **Multi-user Env Managers**: Installs Poetry, Pyenv, and Pipenv in a multi-user friendly way with dev-group permissions and global shims.

## Quick Start

```bash
# Clone the repository
git clone [https://github.com/Wchoi189/ml-dev-bootstrap.git](https://github.com/Wchoi189/ml-dev-bootstrap.git)
cd ml-dev-bootstrap

# Make the script executable
chmod +x setup.sh

# Run the complete setup using the interactive menu
sudo ./setup.sh --menu
````

## Usage

You can run the entire suite of modules or select specific ones.
> For more advanced options, module details, and configuration, please see the full [**Usage Guide**](USAGE.md).
```bash
# Run all modules with a progress bar
sudo ./setup.sh --all --progress

# Run only the system and user setup
sudo ./setup.sh system user

# See a list of all available modules
./setup.sh --list

# Run a dry-run to see what would happen
sudo ./setup.sh --all --dry-run
```

### Environment managers (Poetry, Pyenv, Pipenv)

Use the menu option "e) Run environment manager(s)" to select which to install. The env manager module installs tools in a way that members of the dev group can use them across accounts.

- Poetry installs system-wide by default to `/opt/pypoetry` with a global shim at `/usr/local/bin/poetry`. If the official installer fails, a venv fallback is used under `/opt/pypoetry/venv`.
- Pyenv installs per target user, then sets dev-group permissions and creates `/usr/local/bin/pyenv` to expose it.
- Pipenv installs per target user with dev-group permissions and an optional global shim at `/usr/local/bin/pipenv`.

The module also drops `/etc/profile.d/ml-dev-tools.sh` to ensure common paths (including `/usr/local/bin`, `/opt/pypoetry/bin`, and `$HOME/.local/bin`) are on PATH across new shells.

## Configuration

The main configuration is located in `config/defaults.conf`. You can edit this file directly or override its values by setting environment variables before running the script.

```bash
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="your.email@example.com"
sudo -E ./setup.sh git
```

Environment manager configuration (in `config/defaults.conf`):

```bash
# Poetry
INSTALL_POETRY=yes
POETRY_INSTALL_MODE=system   # system|user (default: system)
POETRY_HOME=/opt/pypoetry    # effective when system mode is used

# Pyenv
INSTALL_PYENV=yes
PYENV_PYTHON_VERSION="3.10.18"  # or comma-separated via PYENV_PYTHON_VERSIONS

# Pipenv
INSTALL_PIPENV=no
```

Tip: If `poetry` is not found immediately in your current shell, refresh your PATH cache or start a login shell:

```bash
hash -r
exec $SHELL -l
poetry --version
```

## Setting a specific password(Optional)
1.  **Enable the password feature** and define your chosen password by exporting two environment variables:
    ```bash
    export SET_USER_PASSWORD=true
    export USER_PASSWORD="your_secure_password_here"
    ```
2.  **Run the setup script** using the `-E` flag to preserve the variables:
    ```bash
    sudo -E ./setup.sh --all
    ```
## Contributing

Contributions are welcome\! Please see the `CONTRIBUTING.md` file for guidelines on how to add new modules and submit changes. This project follows Semantic Versioning.

## License

This project is licensed under the MIT License.