# Agent Guidelines

This repository includes an **.agent** directory that holds knowledge and instructions for AI agents that may assist with development, documentation, or troubleshooting.

## Purpose
- Provide a single source of truth for agents about the project’s tech stack, architecture, and common tasks.
- Define conventions for future contributions (coding style, commit messages, testing, CI).
- Offer reusable snippets and commands that agents can embed in their responses.

## Structure
- `.agent/knowledge.md` – High‑level overview of the project (technologies, design decisions, limitations).
- `.agent/setup.md` – Steps to set up the development environment (Xcode version, required tools, network permissions).
- `.agent/faq.md` – Frequently asked questions for developers and end‑users.
- `.agent/snippets/` – Reusable code snippets (e.g., shell command templates for UDP communication).

## Guidelines for Agents
1. **Ask Before Changing Anything** – Only modify code, docs, or configuration when explicitly requested.
2. **Use Existing Conventions** – Follow the existing SwiftUI patterns, naming conventions, and commit message style (short imperative summary).
3. **Safety First** – Never run destructive Git commands (e.g., force‑push) unless the user explicitly approves.
4. **Provide Context** – When suggesting a change, reference the relevant file paths and include a brief rationale.
5. **Testing** – Recommend running the app in Xcode after any UI or networking changes to verify functionality.
6. **Documentation** – Keep README concise; use `AGENTS.md` for internal AI instructions.

## Example Usage
- An agent can read `.agent/knowledge.md` to answer “What tech stack does this project use?”.
- When a developer asks to add a new feature, the agent can refer to `.agent/setup.md` for build instructions.

*These guidelines help ensure consistent, safe, and helpful assistance from AI agents across this repository.*
