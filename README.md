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

## Configuration

The main configuration is located in `config/defaults.conf`. You can edit this file directly or override its values by setting environment variables before running the script.

```bash
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="your.email@example.com"
sudo -E ./setup.sh git
```

## Contributing

Contributions are welcome\! Please see the `CONTRIBUTING.md` file for guidelines on how to add new modules and submit changes. This project follows Semantic Versioning.

## License

This project is licensed under the MIT License.