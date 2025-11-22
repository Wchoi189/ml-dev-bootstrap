# Project Assessment & Roadmap: ML-Dev-Bootstrap

**Date:** November 22, 2025  
**Version:** 2.0 (Revised)

## 1. Executive Summary
The `ml-dev-bootstrap` project is a mature Bash-based provisioning tool for Ubuntu development environments. It features a modular design, separating concerns into distinct scripts (`modules/`) and orchestration logic (`lib/`).

While the modularity is a strength, the project suffers from the inherent limitations of Bash for complex logic, specifically regarding state management, configuration parsing, and cross-platform compatibility.

## 2. Pain Points of Maintenance

### 🔴 Fragile Configuration & Path Handling
- **Issue:** Each module manually resolves `REPO_ROOT` and sources `config/defaults.conf`.
- **Evidence:** Recent bugs involving `conf/` vs `config/` renaming caused cascading failures across multiple files.
- **Impact:** Moving files or renaming directories requires updating every single module file.
- **Pain Level:** High

### 🔴 Idempotency & State Management
- **Issue:** Bash scripts must manually check "if file exists" or "if command exists" before installing.
- **Evidence:** The `uv.sh` and `ghcli.sh` scripts contain custom logic to detect if a binary is in `/opt` or `/usr/bin`.
- **Impact:** Re-running the script (`./setup.sh --all`) can be unpredictable or slow if checks aren't perfect.
- **Pain Level:** Medium-High

### 🔴 Global Variable Dependency
- **Issue:** Modules rely on global variables (`$USERNAME`, `$INSTALL_UV`, `$GITHUB_PAT`) injected by the orchestrator or config file.
- **Impact:** It is difficult to test a module in isolation without setting up the exact environment variables it expects.
- **Pain Level:** Medium

### 🔴 Platform Lock-in
- **Issue:** Heavy reliance on `apt-get`, `dpkg`, and Ubuntu-specific paths (`/etc/profile.d`).
- **Impact:** Porting this to macOS (Homebrew) or Fedora (dnf) would require a complete rewrite of the package management logic.

## 3. Architectural Improvements

### A. Centralized Context Loading (The "Context Object" Pattern)
Instead of every module calculating `REPO_ROOT` and sourcing config, create a `lib/context.sh`.
- **Change:** Modules should source **only** `lib/context.sh`.
- **Benefit:** Path logic and config loading happen in **one place**. If you rename `config` to `conf`, you only change one file.

### B. Dependency Resolution Engine
Currently, `MODULE_ORDER` in `setup.sh` defines the sequence.
- **Improvement:** Allow modules to declare dependencies (e.g., `uv` depends on `system`).
- **Implementation:** A simple topological sort in the orchestrator would allow for parallel execution of non-dependent modules.

### C. "Dry Run" as a First-Class Citizen
While `--dry-run` exists, it often just prints logs.
- **Improvement:** Abstract all side-effect commands (mkdir, apt, curl) into wrappers (e.g., `sys_install`, `sys_mkdir`).
- **Benefit:** These wrappers can strictly enforce dry-run mode, ensuring no system changes occur during testing.

## 4. Areas for Refactoring

| Component | Issue | Recommendation |
|-----------|-------|----------------|
| **Module Headers** | Repetitive path resolution code. | Extract to `lib/bootstrap_module.sh` and source that single file at the top of every module. |
| **`setup.sh`** | Contains config loading, defaults, and module definitions. | Move module definitions and default constants to `lib/constants.sh` to keep the entry point clean. |
| **`ghcli.sh` / `git.sh`** | Complex credential discovery logic. | Extract `discover_github_token` into `utils/auth.sh` so it can be reused by other tools (e.g., if you add a module for `wandb`). |
| **Config Parsing** | Sourcing shell files is risky. | Move to a `.env` or `.yaml` format and write a parser. This prevents accidental code execution in config files. |

## 5. Coding Standards Recommendations

To maintain sanity in a large Bash codebase:

1.  **Strict Mode**: Always use `set -euo pipefail` at the start of every script.
2.  **ShellCheck**: Integrate `shellcheck` into the CI pipeline. Zero tolerance for warnings.
3.  **Variable Naming**:
    - `GLOBAL_VARS` (Upper case)
    - `local_vars` (Lower case)
    - `_internal_funcs` (Underscore prefix)
4.  **Function Decorators**: Use a standard comment block for every function explaining inputs (`$1`, `$2`) and return codes.
5.  **Scoped Variables**: Use `local` for **every** variable inside a function. Leakage of variables is a major source of bugs in Bash.

## 6. Web Worker Offloading Strategy

Since Bash scripts run in a terminal, "Web Workers" (a browser concept) are not directly applicable to the runtime. **However**, if you are building a **Web-Based Configurator UI** (e.g., "ML-Dev-Bootstrap Generator") to allow users to customize their setup before downloading, here is what you should offload to a Web Worker:

### Use Case: The "Bootstrap Generator" Web App

If you build a frontend (React/Vue) to let users toggle modules and configure paths:

1.  **Dependency Graph Calculation**:
    - **Task**: Calculating the correct installation order based on selected modules (e.g., User selects `PyTorch`, which requires `Conda`, which requires `System`).
    - **Why Worker?**: If the dependency graph becomes complex, calculating the topological sort shouldn't block the UI thread.

2.  **Config Validation & Parsing**:
    - **Task**: Parsing uploaded `defaults.conf` files or validating complex regex (e.g., validating SSH key formats or Python version strings against available releases).
    - **Why Worker?**: Regex validation on large inputs or fetching version lists from external APIs (if done via proxy) can be heavy.

3.  **Script Generation**:
    - **Task**: Assembling the final `setup.sh` zip file dynamically in the browser.
    - **Why Worker?**: String concatenation and Zip file compression (using libraries like `JSZip`) are CPU intensive. Doing this in a worker keeps the "Download" button responsive.

### Example Web Worker Architecture

```javascript
// worker.js
self.onmessage = function(e) {
    const { selectedModules, config } = e.data;
    
    // 1. Calculate Dependencies
    const order = resolveDependencies(selectedModules);
    
    // 2. Generate Script Content
    const script = generateBashScript(order, config);
    
    // 3. Return Blob
    self.postMessage({ scriptBlob: script });
}
```

## 7. Roadmap

### Q4 2025: Stability & Cleanup
- [ ] **Refactor**: Centralize path/config loading into `lib/context.sh`.
- [ ] **Security**: Move all token discovery logic to `utils/auth.sh`.
- [ ] **CI**: Add GitHub Action for `shellcheck`.

### Q1 2026: Modernization
- [ ] **Testing**: Implement `bats` (Bash Automated Testing System) for unit testing modules.
- [ ] **Container**: Create a `Dockerfile` that mimics the bootstrap process to verify it works in a clean environment.

### Q2 2026: Evolution
- [ ] **Migration**: Begin rewriting complex logic (like `envmgr`) in Python or Go for better robustness.
- [ ] **Web UI**: Launch the "Bootstrap Generator" web app using Web Workers for script generation.
