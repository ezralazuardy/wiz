# Agent Guidelines

This repository includes an **.agent** directory that holds knowledge and instructions for AI agents that may assist with development, documentation, or troubleshooting.

## Purpose
- Provide a single source of truth for agents about the project's tech stack, architecture, and common tasks.
- Define conventions for future contributions (coding style, commit messages, testing, CI).
- Offer reusable snippets and commands that agents can embed in their responses.

## Structure
- `.agent/knowledge.md` – High-level overview of the project (technologies, design decisions, limitations).
- `.agent/setup.md` – Steps to set up the development environment (Xcode version, required tools, network permissions).
- `.agent/faq.md` – Frequently asked questions for developers and end-users.
- `.agent/snippets/` – Reusable code snippets (e.g., shell command templates for UDP communication).

## Guidelines for Agents
1. **Ask Before Changing Anything** – Only modify code, docs, or configuration when explicitly requested.
2. **Use Existing Conventions** – Follow the existing SwiftUI patterns, naming conventions, and commit message style (short imperative summary).
3. **Safety First** – Never run destructive Git commands (e.g., force-push) unless the user explicitly approves.
4. **Provide Context** – When suggesting a change, reference the relevant file paths and include a brief rationale.
5. **Testing** – Recommend running the app in Xcode after any UI or networking changes to verify functionality.
6. **Documentation** – Keep README concise; use `AGENTS.md` for internal AI instructions.
7. **Build & Launch** – Before launching a new build, always kill the running app process first: `pkill -f "Wiz"` then `open dist/Wiz.app`.

## Recent Major Changes

### Connectivity & Status Reliability
- Separated power state (`ON/OFF`) from connectivity (`Connected/Disconnected`) in sync logic.
- Device is marked `Disconnected` only after repeated no-response checks and network reachability verification.
- Menu bar status now reflects real power state (`On/Off`) for connected devices, and `Disconnected` only when unreachable.

### Device Detail UX
- Detail page shows blue `Refreshing` status while initial/explicit refresh is in progress.
- Toggle flow now avoids races with auto-sync (prevents flaky button state after rapid updates).
- Brightness slider minimum is now `10%` for smart bulbs.
- Slider value is synced when brightness is changed from menu bar presets.

### Settings & Sync
- Auto Sync default is now enabled (`3s` interval).
- Added `Sync Data to iCloud` toggle in Settings.
- iCloud sync now covers devices, rooms, and key app settings (auto sync, menu bar, animations, permissions flags) via `NSUbiquitousKeyValueStore`.

### Menu Bar & Window Behavior
- `Open Wiz` now reliably restores the hidden/minimized main window.
- In menu bar mode, closing the window hides it instead of terminating the app window lifecycle.

## Example Usage
- An agent can read `.agent/knowledge.md` to answer "What tech stack does this project use?".
- When a developer asks to add a new feature, the agent can refer to `.agent/setup.md` for build instructions.

*These guidelines help ensure consistent, safe, and helpful assistance from AI agents across this repository.*
