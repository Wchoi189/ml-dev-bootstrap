# Contributing to ml-dev-bootstrap

We welcome contributions! Please follow these guidelines to help us keep the project consistent and easy to maintain.

## How to Add a New Module

1.  Create your new module file in the `modules/` directory.
2.  Implement a `run_modulename()` function as the main entry point.
3.  Add your module's name to the `MODULE_ORDER` array in the main `setup.sh` script.
4.  Add a short description to the `MODULES` associative array.
5.  Create corresponding tests for your module in the `test_setup.sh` file.

## Submitting Changes

1.  Fork the repository.
2.  Create a new branch for your feature (`git checkout -b feature/your-feature-name`).
3.  Commit your changes (`git commit -m 'Add some feature'`).
4.  Push to the branch (`git push origin feature/your-feature-name`).
5.  Open a Pull Request.

## Versioning

This project uses **Semantic Versioning** ([SemVer](https://semver.org/)).