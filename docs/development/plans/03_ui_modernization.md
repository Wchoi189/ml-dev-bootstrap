---
title: "03 - UI/UX Modernization & Cleanup"
author: "GitHub Copilot"
timestamp: "2025-11-22"
branch: "main"
type: "refactor"
category: "ui"
status: "draft"
tags: ["ui", "cleanup", "ssh"]
---

> **⚠️ IMPORTANT:** This artifact must be generated using the AgentQMS toolbelt script (`python -m agent_qms.toolbelt.core create_artifact --type implementation_plan`). Manual creation may violate naming and validation rules.

# Master Prompt

You are an autonomous AI agent, my Chief of Staff for implementing the **03 - UI/UX Modernization & Cleanup**. Your primary responsibility is to execute the "Living Implementation Blueprint" systematically, handle outcomes, and keep track of our progress. Do not ask for clarification on what to do next; your next task is always explicitly defined.

---

**Your Core Workflow is a Goal-Execute-Update Loop:**
1. **Goal:** A clear `🎯 Goal` will be provided for you to achieve.
2. **Execute:** You will start working on the task defined in the `NEXT TASK`
3. **Handle Outcome & Update:** Based on the success or failure of the command, you will follow the specified contingency plan. Your response must be in two parts:
   * **Part 1: Execution Report:** Provide a concise summary of the results and analysis of the outcome (e.g., "All tests passed" or "Test X failed due to an IndexError...").
   * **Part 2: Blueprint Update Confirmation:** Confirm that the living blueprint has been updated with the new progress status and next task. The updated blueprint is available in the workspace file.

---

# Living Implementation Blueprint: 03 - UI/UX Modernization & Cleanup

## Progress Tracker
**⚠️ CRITICAL: This Progress Tracker MUST be updated after each task completion, blocker encounter, or technical discovery. Required for iterative debugging and incremental progress tracking.**

- **STATUS:** Not Started
- **CURRENT STEP:** Phase 1, Task 1.1 - Cleanup Aliases
- **LAST COMPLETED TASK:** N/A (Requires Plan 02 completion)
- **NEXT TASK:** Remove `MODULES_CONDA` alias and verify `sources` and `locale` modules are preserved.

### Implementation Outline (Checklist)

#### **Phase 1: Cleanup & Simplification (Week 3)**
1. [ ] **Task 1.1: Cleanup Aliases**
   - [ ] Remove `MODULES_CONDA` alias (keep `envmgr` as the primary).
   - [ ] **Preserve** `modules/sources.sh` and `modules/locale.sh` (do not delete).
   - [ ] Ensure `setup.sh` still includes `sources` and `locale` in `MODULE_ORDER`.

2. [ ] **Task 1.2: Refactor SSH Module**
   - [ ] Modify `modules/ssh.sh` to be "permission-fix first".
   - [ ] Remove hardcoded `known_hosts` injection.
   - [ ] Make key generation interactive-only (ask for confirmation).
   - [ ] Ensure `utils/fix-ssh-permissions.sh` is preserved and called correctly.

#### **Phase 2: UI Modernization (Week 3)**
3. [ ] **Task 2.1: Implement TUI Library (`lib/tui.sh`)**
   - [ ] Create `lib/tui.sh`.
   - [ ] Implement a wrapper around `whiptail` (check for existence, fallback to text if missing).
   - [ ] Create `tui_checklist` function for selecting modules.
   - [ ] Create `tui_msgbox` for information.

4. [ ] **Task 2.2: Replace Legacy Menu**
   - [ ] Rewrite `lib/menu.sh` to use `lib/tui.sh`.
   - [ ] Implement a dynamic module selection screen (reading `MODULE_ORDER`).
   - [ ] Ensure `sources` and `locale` are selectable in the new menu.
   - [ ] Remove the complex comma-separated parsing logic for environment managers; use a checklist instead.

#### **Phase 3: Final Polish (Week 3)**
5. [ ] **Task 3.1: Update Documentation**
   - [ ] Update `README.md` to reflect the UI changes.
   - [ ] Update `USAGE.md` with screenshots/descriptions of the new TUI.

---

## 📋 **Technical Requirements Checklist**

### **Architecture & Design**
- [ ] **Dependency Check:** The TUI must check for `whiptail` (`apt-get install whiptail` if missing, or fallback).
- **Simplified Flow:** The default `setup.sh` (no args) should probably show the TUI menu instead of help text.

### **Integration Points**
- [ ] **`setup.sh`**: Needs to be updated to launch the new menu when `--menu` is passed (or default).

### **Quality Assurance**
- [ ] **Usability:** The new menu must be navigable with keyboard (Arrow keys, Space, Enter).
- [ ] **Safety:** Ensure `sources.sh` includes confirmation before modifying system sources.

---

## 🎯 **Success Criteria Validation**

### **Functional Requirements**
- [ ] `setup.sh --menu` launches a blue-screen `whiptail` interface.
- [ ] Users can select multiple environment managers (e.g., `uv` and `poetry`) using a checklist.
- [ ] SSH module fixes permissions without overwriting keys silently.

### **Technical Requirements**
- [ ] Codebase is cleaner (removed aliases).
- [ ] Menu logic is decoupled from the specific list of modules.

---

## 📊 **Risk Mitigation & Fallbacks**

### **Current Risk Level**: LOW
### **Active Mitigation Strategies**:
1. **Fallback Mode:** If `whiptail` is not installed, `lib/tui.sh` should fall back to a simple `select` loop or print an error asking to install it.

### **Fallback Options**:
1. **Keep Legacy:** Keep the old `show_menu` function as `show_legacy_menu` in case TUI fails.

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

**TASK:** Remove `MODULES_CONDA` alias and verify `sources` and `locale` modules are preserved.

**OBJECTIVE:** Reduce technical debt by removing redundant aliases while keeping useful regional features.

**APPROACH:**
1. Edit `setup.sh` to remove `MODULES_CONDA`.
2. Verify `modules/sources.sh` and `modules/locale.sh` exist.

**SUCCESS CRITERIA:**
- `setup.sh --list` continues to show `sources` and `locale`.
- `setup.sh --list` no longer shows `conda` (only `envmgr`).

---

*This implementation plan follows the Blueprint Protocol Template (PROTO-GOV-003) for systematic, autonomous execution with clear progress tracking.*
