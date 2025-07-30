# Changelog

All notable changes to this project will be documented in this file.

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

