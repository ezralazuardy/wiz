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

### Multi-Device Type Support
- Added support for Smart Bulb, Smart Plug, Smart Switch, and Smart Strip
- Device type auto-detection via `getSystemConfig` API
- Each device type has its own icon and capabilities
- Smart bulbs include brightness slider control

### UI Improvements
- Removed redundant device name text from detail view (now shown in navigation title only)
- Device list shows device type instead of IP address
- Card-based layout in Add Device modal with device counter (e.g., "Smart Bulb #1")
- Consistent button placement at bottom right in all modals

### Settings
- Auto-sync interval changed from 30s to 3s for better responsiveness
- Added "App Animations" toggle (default enabled) for UI animation control
- Room icons reduced to 8 options (removed car and books.vertical)

### Data Model
- `WizDevice` now includes `type` (DeviceType enum) and `brightness` (Int 0-100) fields
- Device type detection in discovery process
- Brightness control API for smart bulbs

## Example Usage
- An agent can read `.agent/knowledge.md` to answer "What tech stack does this project use?".
- When a developer asks to add a new feature, the agent can refer to `.agent/setup.md` for build instructions.

*These guidelines help ensure consistent, safe, and helpful assistance from AI agents across this repository.*
