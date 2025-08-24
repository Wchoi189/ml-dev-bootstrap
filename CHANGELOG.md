# Changelog

All notable changes to this project will be documented in this file.

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

