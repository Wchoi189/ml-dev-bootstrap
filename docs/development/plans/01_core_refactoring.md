---
title: "01 - Core Refactoring & Auth Stabilization"
author: "GitHub Copilot"
timestamp: "2025-11-22"
branch: "main"
type: "refactor"
category: "core"
status: "draft"
tags: ["refactor", "auth", "architecture"]
---

# Master Prompt

You are an autonomous AI agent, my Chief of Staff for implementing the **01 - Core Refactoring & Auth Stabilization**. Your primary responsibility is to execute the "Living Implementation Blueprint" systematically, handle outcomes, and keep track of our progress. Do not ask for clarification on what to do next; your next task is always explicitly defined.

---

**Your Core Workflow is a Goal-Execute-Update Loop:**
1. **Goal:** A clear `🎯 Goal` will be provided for you to achieve.
2. **Execute:** You will start working on the task defined in the `NEXT TASK`
3. **Handle Outcome & Update:** Based on the success or failure of the command, you will follow the specified contingency plan. Your response must be in two parts:
   * **Part 1: Execution Report:** Provide a concise summary of the results and analysis of the outcome (e.g., "All tests passed" or "Test X failed due to an IndexError...").
   * **Part 2: Blueprint Update Confirmation:** Confirm that the living blueprint has been updated with the new progress status and next task. The updated blueprint is available in the workspace file.

---

# Living Implementation Blueprint: 01 - Core Refactoring & Auth Stabilization

## Progress Tracker
**⚠️ CRITICAL: This Progress Tracker MUST be updated after each task completion, blocker encounter, or technical discovery. Required for iterative debugging and incremental progress tracking.**

- **STATUS:** Not Started
- **CURRENT STEP:** Phase 1, Task 1.1 - Create Centralized Context
- **LAST COMPLETED TASK:** N/A
- **NEXT TASK:** Create `lib/context.sh` to centralize path resolution and config loading.

### Implementation Outline (Checklist)

#### **Phase 1: Foundation & Context (Week 1)**
1. [ ] **Task 1.1: Create Centralized Context (`lib/context.sh`)**
   - [ ] Implement `resolve_repo_root` function to reliably find project root.
   - [ ] Implement `load_config` function to source `config/defaults.conf`.
   - [ ] **NEW:** Implement override logic: check for and source `config/local.conf` if it exists.
   - [ ] Export standard global variables (`REPO_ROOT`, `CONFIG_DIR`, `LOG_FILE`).
   - [ ] Ensure `lib/context.sh` is idempotent (guards against multiple sourcing).

2. [ ] **Task 1.2: Standardize Entry Point (`setup.sh`)**
   - [ ] Refactor `setup.sh` to source `lib/context.sh` immediately.
   - [ ] Remove duplicate path calculation logic from `setup.sh`.
   - [ ] Ensure `setup.sh` uses the centralized configuration.
   - [ ] Add `config/local.conf` to `.gitignore`.
   - [ ] Create `config/local.conf.example` as a template for users.

#### **Phase 2: Authentication & Security (Week 1)**
3. [ ] **Task 2.1: Extract Auth Logic (`utils/auth.sh`)**
   - [ ] Create `utils/auth.sh`.
   - [ ] Move GitHub token discovery logic from `ghcli.sh` and `git.sh` to `utils/auth.sh`.
   - [ ] Implement `get_github_token` function with proper error handling and precedence (Env Var > Config > Interactive).
   - [ ] Fix the "GH CLI and Git token extraction logic flaw" by ensuring consistent token retrieval.

4. [ ] **Task 2.2: Update Modules to use Auth Utility**
   - [ ] Refactor `modules/ghcli.sh` to use `utils/auth.sh`.
   - [ ] Refactor `modules/git.sh` to use `utils/auth.sh`.
   - [ ] Verify that token is correctly passed to these modules.

#### **Phase 3: Safety & Standards (Week 1)**
5. [ ] **Task 3.1: Enforce Strict Mode**
   - [ ] Add `set -euo pipefail` to `setup.sh` and all `lib/*.sh` scripts.
   - [ ] Audit `modules/*.sh` and add `set -euo pipefail` where missing.
   - [ ] Fix any immediate crashes caused by unbound variables or failing commands (using `|| true` where appropriate).

---

## 📋 **Technical Requirements Checklist**

### **Architecture & Design**
- [ ] **Centralized Context:** All scripts must derive their environment from a single source of truth (`lib/context.sh`).
- [ ] **Modular Auth:** Authentication logic must be decoupled from specific modules.
- [ ] **No UI Complexity:** Keep interactions CLI-focused; avoid adding complex TUI/GUI elements.

### **Integration Points**
- [ ] **`setup.sh`**: Must remain the primary entry point.
- [ ] **`config/defaults.conf`**: Must continue to be the source of default settings.

### **Quality Assurance**
- [ ] **ShellCheck:** Run `shellcheck` on modified files to ensure no new warnings are introduced.
- [ ] **Idempotency:** Re-running `setup.sh` should not break the environment or duplicate configuration.

---

## 🎯 **Success Criteria Validation**

### **Functional Requirements**
- [ ] `setup.sh` runs successfully without errors after refactoring.
- [ ] GitHub token is correctly detected and used by `ghcli.sh` and `git.sh`.
- [ ] Project root is correctly resolved regardless of where the script is called from.

### **Technical Requirements**
- [ ] Code duplication regarding path resolution is eliminated.
- [ ] "GH CLI and Git token extraction logic flaw" is resolved.
- [ ] All modified scripts pass `shellcheck` (or have explicit ignores with justification).

---

## 📊 **Risk Mitigation & Fallbacks**

### **Current Risk Level**: MEDIUM
### **Active Mitigation Strategies**:
1. **Incremental Refactoring:** We are changing core logic (`setup.sh`), so we will test after each task.
2. **Backup:** Ensure the original scripts are version controlled (git) before modifying.

### **Fallback Options**:
1. **Revert:** If `setup.sh` breaks, revert to the previous commit.
2. **Inline Fixes:** If `lib/context.sh` causes circular dependencies, temporarily inline the logic back into `setup.sh` and debug.

---

## 🔄 **Blueprint Update Protocol**

**Update Triggers:**
- Task completion (move to next task)
- Blocker encountered (document and propose solution)
- Technical discovery (update approach if needed)
- Quality gate failure (address issues before proceeding)

**Update Format:**
1. Update Progress Tracker (STATUS, CURRENT STEP, LAST COMPLETED TASK, NEXT TASK)
2. Mark completed items with [x]
3. Add any new discoveries or changes to approach
4. Update risk assessment if needed

---

## 🚀 **Immediate Next Action**

**TASK:** Create `lib/context.sh` to centralize path resolution and config loading.

**OBJECTIVE:** Establish a single source of truth for the project environment, eliminating brittle relative path logic scattered across files.

**APPROACH:**
1. Create `lib/context.sh`.
2. Implement `resolve_repo_root` using `git rev-parse --show-toplevel` or reliable relative path logic.
3. Implement `load_config` to source `config/defaults.conf`.
4. Export `REPO_ROOT` and `CONFIG_DIR`.

**SUCCESS CRITERIA:**
- `source lib/context.sh` sets `REPO_ROOT` correctly when run from any subdirectory.
- `source lib/context.sh` loads variables from `config/defaults.conf`.

---

*This implementation plan follows the Blueprint Protocol Template (PROTO-GOV-003) for systematic, autonomous execution with clear progress tracking.*
