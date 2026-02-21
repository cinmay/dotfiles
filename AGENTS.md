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
- Reference docs and setup notes are in `README.md`

## Build, Test, and Development Commands
- `stow -t "$HOME" omarchy` — symlink the Omarchy config into `$HOME`.

## Coding Style & Naming Conventions
- Match the surrounding file style; this repo mixes Lua, shell, and TS.
- Prefer clear, explicit names over comments; only comment when the “why” is not obvious.

## Refactoring & Abstractions
- Follow the Rule of Three: refactor only after duplication appears in three places.
- Avoid introducing helpers or abstractions without a concrete, current need.
- Keep related config and scripts close together to preserve locality.

## Commit & Pull Request Guidelines
- Recent commits use short, capitalized messages (e.g., “Fix …”, “Updated …”); occasional `wip` appears—avoid it for final changes.
- PRs should explain intent, list affected configs, and note any manual verification (e.g., “verified in AwesomeWM”).
- Include screenshots or recordings for UI/WM changes when practical.

## Security & Configuration Notes
- Avoid committing secrets or machine-specific credentials.
- If sensitive data is needed, place it under `encrypted/` and document how it is provisioned.
