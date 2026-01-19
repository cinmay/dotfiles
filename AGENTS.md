# Repository Guidelines

## Core Philosophy
- Optimize for clarity, locality, and long-term maintainability.
- Prefer simple, explicit solutions over clever or overly flexible ones.
- Code should read well for a first-time contributor; the shell/runtime is secondary.

## Why This Repo Exists
Why: The purpose of my setup is to reinforce my pursuit of personal excellence in professional software development.

## Philosophy & Guiding Principles
This setup is a deliberate professional workspace for focus and personal excellence. Everything is intentional: every tool exists for a reason, every screen element earns its place, and anything that distracts or dilutes the work is removed. The environment is built for single-tasking, with one monitor, keyboard-first navigation, and one workspace per task so attention stays on the work. I prefer hard-mode learning because mastery matters more than convenience, and a bespoke Neovim workflow forces me to understand my tools deeply. The system is designed so everything has a hotkey and a clear purpose, reinforcing discipline, flow, and craftsmanship.

## Project Structure & Module Organization
- Top-level folders map to app configs: `alacritty/`, `ghostty/`, `nvim/`, `rofi/`, `picom/`, `awesome/`, `omarchy/`.
- Utility scripts live in `tools/` (shell helpers, TypeScript utilities, and small experiments).
- Reference docs and setup notes are in `README.md` and `wm_keybindings.conf`.

## Build, Test, and Development Commands
- `stow -t "$HOME" omarchy` — symlink the Omarchy config into `$HOME`.
- `tools/font-check.sh` / `tools/test-fonts.sh` — validate font installation.
- `tools/setup_nvim_defaults.sh` — bootstrap default Neovim settings.
- `cd tools/hotkeyCheetSheet && npx nodemon hotKeyCheetSheet.ts` — rebuild the hotkey cheat sheet during edits.
- `cd tools/typescriptTest && npm test` — run Jest in the TypeScript test sandbox.

## Coding Style & Naming Conventions
- Match the surrounding file style; this repo mixes Lua, shell, and TS.
- Lua configs (e.g., `awesome/rc.lua`) use 4-space indentation.
- JSON/TS in `tools/` typically use 2-space indentation; keep existing alignment.
- Prefer descriptive file names; configs are folder-based (app name as folder).
- Prefer clear, explicit names over comments; only comment when the “why” is not obvious.

## Refactoring & Abstractions
- Follow the Rule of Three: refactor only after duplication appears in three places.
- Avoid introducing helpers or abstractions without a concrete, current need.
- Keep related config and scripts close together to preserve locality.

## Testing Guidelines
- Tests are limited to `tools/typescriptTest` and use Jest.
- Test files follow `*.test.ts` naming; keep tests close to the sample code.
- If you add new tooling, include a minimal test script or a smoke-test command.

## Commit & Pull Request Guidelines
- Recent commits use short, capitalized messages (e.g., “Fix …”, “Updated …”); occasional `wip` appears—avoid it for final changes.
- PRs should explain intent, list affected configs, and note any manual verification (e.g., “verified in AwesomeWM”).
- Include screenshots or recordings for UI/WM changes when practical.

## Security & Configuration Notes
- Avoid committing secrets or machine-specific credentials.
- If sensitive data is needed, place it under `encrypted/` and document how it is provisioned.
