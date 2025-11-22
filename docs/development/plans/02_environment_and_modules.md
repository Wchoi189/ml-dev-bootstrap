---
title: "02 - Modularization & Environment Detection"
author: "GitHub Copilot"
timestamp: "2025-11-22"
branch: "main"
type: "refactor"
category: "modules"
status: "draft"
tags: ["refactor", "modules", "environment"]
---

# Master Prompt

You are an autonomous AI agent, my Chief of Staff for implementing the **02 - Modularization & Environment Detection**. Your primary responsibility is to execute the "Living Implementation Blueprint" systematically, handle outcomes, and keep track of our progress. Do not ask for clarification on what to do next; your next task is always explicitly defined.

---

**Your Core Workflow is a Goal-Execute-Update Loop:**
1. **Goal:** A clear `🎯 Goal` will be provided for you to achieve.
2. **Execute:** You will start working on the task defined in the `NEXT TASK`
3. **Handle Outcome & Update:** Based on the success or failure of the command, you will follow the specified contingency plan. Your response must be in two parts:
   * **Part 1: Execution Report:** Provide a concise summary of the results and analysis of the outcome (e.g., "All tests passed" or "Test X failed due to an IndexError...").
   * **Part 2: Blueprint Update Confirmation:** Confirm that the living blueprint has been updated with the new progress status and next task. The updated blueprint is available in the workspace file.

---

# Living Implementation Blueprint: 02 - Modularization & Environment Detection

## Progress Tracker
**⚠️ CRITICAL: This Progress Tracker MUST be updated after each task completion, blocker encounter, or technical discovery. Required for iterative debugging and incremental progress tracking.**

- **STATUS:** Not Started
- **CURRENT STEP:** Phase 1, Task 1.1 - Create Module Bootstrap Header
- **LAST COMPLETED TASK:** N/A (Requires Plan 01 completion)
- **NEXT TASK:** Create `lib/bootstrap_module.sh` to standardize module initialization.

### Implementation Outline (Checklist)

#### **Phase 1: Module Standardization (Week 2)**
1. [ ] **Task 1.1: Create Module Bootstrap Header (`lib/bootstrap_module.sh`)**
   - [ ] Create `lib/bootstrap_module.sh`.
   - [ ] Include `source lib/context.sh`.
   - [ ] Include standard logging initialization.
   - [ ] Include standard error handling (trap).

2. [ ] **Task 1.2: Refactor Modules**
   - [ ] Refactor `modules/*.sh` to source `lib/bootstrap_module.sh` at the top.
   - [ ] Remove redundant `REPO_ROOT` calculation and config sourcing from each module.
   - [ ] Ensure all modules use the standard logging functions.

#### **Phase 2: Environment Detection (Week 2)**
3. [ ] **Task 2.1: Enhance Environment Detection (`lib/platform.sh`)**
   - [ ] Create `lib/platform.sh` (or add to `lib/context.sh`).
   - [ ] Implement `detect_os` (Linux, macOS).
   - [ ] Implement `detect_distro` (Ubuntu, Debian, Fedora, etc.).
   - [ ] Export `OS_TYPE`, `DISTRO_NAME`, `DISTRO_VERSION`.

4. [ ] **Task 2.2: Platform-Aware Logic**
   - [ ] Update `modules/system.sh` to use `detect_distro`.
   - [ ] (Optional) Add support for `brew` if macOS is detected (stub or basic implementation).

#### **Phase 3: Cleanup & Optimization (Week 2)**
5. [ ] **Task 3.1: Remove Redundant Code**
   - [ ] Scan `utils/common.sh` for unused functions after refactoring.
   - [ ] Remove any legacy global variables that are no longer needed.

---

## 📋 **Technical Requirements Checklist**

### **Architecture & Design**
- [ ] **Standardized Modules:** All modules must follow a consistent structure.
- [ ] **Platform Agnostic Core:** Core logic should not assume Ubuntu; platform specifics should be guarded.

### **Integration Points**
- [ ] **Modules**: Must continue to work when called by `orchestrator.sh`.

### **Quality Assurance**
- [ ] **Dry Run:** Ensure modules respect the `DRY_RUN` flag (if implemented in Plan 01 or here).

---

## 🎯 **Success Criteria Validation**

### **Functional Requirements**
- [ ] All modules execute correctly with the new header.
- [ ] System correctly identifies the OS and Distro.

### **Technical Requirements**
- [ ] Code reduction in `modules/*.sh` (less boilerplate).
- [ ] Improved maintainability due to centralized module logic.

---

## 📊 **Risk Mitigation & Fallbacks**

### **Current Risk Level**: LOW
### **Active Mitigation Strategies**:
1. **Test One Module First:** Refactor one module (e.g., `modules/prompt.sh`) and verify before doing all.

### **Fallback Options**:
1. **Revert:** Revert changes if modules fail to load context.

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

**TASK:** Create `lib/bootstrap_module.sh`.

**OBJECTIVE:** Define the standard header for all modules.

**APPROACH:**
1. Create file.
2. Add `source "$(dirname "${BASH_SOURCE[0]}")/context.sh"`.
3. Add standard logging setup.

**SUCCESS CRITERIA:**
- A test script sourcing `lib/bootstrap_module.sh` has access to all context variables.

---

*This implementation plan follows the Blueprint Protocol Template (PROTO-GOV-003) for systematic, autonomous execution with clear progress tracking.*
