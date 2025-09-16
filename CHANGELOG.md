# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2025-09-16

### Added

- **Major Codebase Refactoring**:
  - Reduced main `setup.sh` from 1107 to 377 lines (66% reduction)
  - Extracted modular components: `lib/menu.sh`, `lib/args.sh`, `lib/orchestrator.sh`, `modules/diagnostics.sh`
  - Improved maintainability and code organization

- **Enhanced Environment Manager Module**:
  - Added installation context detection (root vs user execution)
  - Context-aware behavior for system-wide vs user installations
  - Updated description to clearly indicate "Pyenv default" installation
  - Added `ENVMGR_CONTEXT_MODE` configuration option (auto/root-only/user-only/always)

- **Interactive Locale Selection**:
  - Added Korean/English locale choice during setup
  - `INTERACTIVE_LOCALE_SELECTION` configuration option
  - Improved user experience for multilingual environments

- **Comprehensive User Management System**:
  - Combined `r) Create user` and `u) Switch user` into single workflow
  - Interactive user creation with username and password prompts
  - Smart user detection (filters system users, shows UID ≥ 1000)
  - Automatic switching to newly created users
  - Enhanced submenu with create/switch options

- **Menu System Improvements**:
  - Moved `sources` module from main flow to quick action `s)`
  - Updated module numbering and menu structure
  - Better visual organization and user guidance

- **System Enhancements**:
  - Added `build-essential` to essential packages (always installed)
  - Improved root user prompt configuration support
  - Enhanced configuration options for all new features

### Changed

- **Menu Structure**:
  - Removed separate user creation/switching options
  - Consolidated into comprehensive user management workflow
  - Updated quick actions layout and descriptions

- **Module Order**:
  - Removed `sources` from main `MODULE_ORDER` array
  - Updated module numbering in interactive menu

- **Configuration System**:
  - Added new configuration options for enhanced features
  - Improved configuration documentation and examples
  - Better environment variable support

### Fixed

- **Prompt Configuration**:
  - Fixed prompt setup for root user execution context
  - Improved compatibility across different user environments

- **User Management**:
  - Resolved issues with user creation and switching workflow
  - Better error handling for user-related operations

### Enhanced

- **User Experience**:
  - More intuitive menu navigation and options
  - Better feedback and status messages
  - Streamlined workflows for common operations

- **Documentation**:
  - Updated README with new features and configuration options
  - Improved usage examples and menu descriptions
  - Added comprehensive changelog entries

## [0.3.0] - 2025-09-08

### Added

- **APT Sources Management Module** (`sources`):
  - Interactive mirror selection from popular regional mirrors (Kakao, Naver, Daum, Ubuntu official, AWS regions)
  - Automatic Ubuntu version detection (supports 20.04 through 24.04)
  - Backup creation before making changes
  - Non-interactive mode for automated setups

- **Enhanced User Management & Permissions**:
  - `/opt`-based setup directory with optimal permissions (`/opt/ml-dev-bootstrap`)
  - Multiple access points: `~/setup` (user symlink), `/root/ml-dev-bootstrap` (compatibility symlink)
  - Smart permission delegation with setgid bit for consistent group ownership
  - Seamless user switching with `--switch-user` option and menu integration

- **Flexible Root Requirements**:
  - Smart detection of when root privileges are required vs optional
  - `ALLOW_NON_ROOT=true` support for user-specific operations
  - Clear messaging about permission requirements

- **User Switching Features**:
  - `--switch-user` command-line option with clear guidance
  - `u) Switch to development user` menu option
  - Multiple access path information for different user contexts

- **Enhanced Logging & Error Handling**:
  - Improved log file permission handling for multi-user scenarios
  - Better error messages and user guidance

- **Colorful Interactive Menu**:
  - Added ANSI color support for better visual appeal and readability
  - Color-coded menu options with distinct colors for different sections
  - Enhanced user experience with colored status indicators and prompts
  - Improved visual hierarchy with colored headers and separators

### Changed

- **File Location Strategy**:
  - Moved main setup files to `/opt/ml-dev-bootstrap` for better accessibility
  - Created symlinks for backward compatibility and user convenience
  - Improved permission model with dev group ownership

- **User Module Enhancements**:
  - `configure_setup_directory_permissions()` now handles `/opt` location optimally
  - Automatic symlink creation for user access points
  - Enhanced permission configuration with setgid support

- **Common Utilities**:
  - `check_requirements()` now intelligently determines root requirements
  - Better support for user-specific operations without root

### Fixed

- **Permission Issues**:
  - Resolved `/root` directory traversal issues for development users
  - Fixed log file permission conflicts between root and user contexts
  - Eliminated permission denied errors when switching users

- **User Switching Problems**:
  - Manual `su dev-user` now works correctly with proper path access
  - Environment manager installations work in user context
  - No more permission conflicts between root and user operations

### Security

- **Permission Hardening**:
  - Proper group-based access control with setgid directories
  - Secure multi-user file permissions (775 for dirs, 664 for files)
  - Maintained root ownership while allowing dev group access

## [0.2.1] - 2025-08-24

### Added

- Environment Manager (envmgr):
    - System-wide Poetry install to `/opt/pypoetry` with dev-group permissions and global shim at `/usr/local/bin/poetry`.
    - Fallback Poetry installation using a dedicated venv when the official installer fails.
    - Global PATH profile `/etc/profile.d/ml-dev-tools.sh` to ensure `/usr/local/bin`, `/opt/pypoetry/bin`, and `$HOME/.local/bin` are available across shells.

### Changed

- Hardened config sourcing across modules using BASH_SOURCE to resolve `config/defaults.conf` reliably.
- Pyenv and Pipenv modules now enforce dev-group permissions and create global shims when running as root.

### Fixed

- Resolved permission holes causing installs to be root-only and inaccessible to other users.
- Fixed path bugs where modules sourced `../config/defaults.conf` incorrectly when executed from different locations.

## [0.2.0] - 2025-07-30

### Added

- **Maintenance & Troubleshooting Tools**:
    - Implemented a `--diagnose` flag to run comprehensive checks on the environment.
    - Added an `--update` flag to update system packages and conda environments.
    - Added a `--backup` flag to create a backup of important configuration files.
- **Profile-based Installation**:
    - Introduced a `GLOBAL_INSTALL_PROFILE` setting in `config/defaults.conf` to choose between `minimal`, `standard`, and `full` setups.
- **User Experience**:
    - Added a `--progress` flag to display a progress bar during a full (`--all`) installation.

### Changed

- **Environment Management**:
    - Replaced the Conda installation with **Micromamba** for significantly faster and more reliable environment creation.
    - The `conda` module now creates a dedicated named environment instead of installing packages into the `base` environment.
- **Efficiency**:
    - Optimized the permission-setting logic for conda environments to avoid long delays on systems with slow disk I/O.
- **Robustness**:
    - Hardened the `locale` and `user` modules to prevent common configuration issues and to provide better diagnostics.

## [0.1.0-beta] - 2025-07-26

### Added

- Initial release of the modular bootstrap utility.
- Modules for system, locale, user, conda, prompt, and git setup.
- Features including interactive menu, dry-run mode, and diagnostics.

## [0.1.0-beta] - 2025-07-26

### Added

-   Initial release of the modular bootstrap utility.
-   Modules for system, locale, user, conda, prompt, and git setup.
-   Features including interactive menu, dry-run mode, and diagnostics.

