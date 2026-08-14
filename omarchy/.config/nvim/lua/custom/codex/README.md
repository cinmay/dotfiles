# Codex Thread Workflow

This feature keeps prompt writing and review inside Neovim, while Codex runs outside the editor.
Each thread file is a single, durable work log that you can resume later.

## Goals
- Write prompts as normal Markdown.
- Keep a single thread file per topic.
- Run Codex from the current thread file.
- Append Codex output back into the same file.
- Resume past sessions when possible.

## User Stories
- As a developer, I want each prompt thread to remember its Codex session so I can continue the conversation quickly while keeping a single work log.
- As a developer, I want the thread to still work even if the session is missing or invalid so I can keep moving without manual recovery.

## File Layout
Threads live under `.ai/threads/` in each repo. Example:

```
.ai/threads/2026-02-01-codex-thread.md
```

## Thread Header
Each thread can store a session ID at the top:

```
--- Codex Session ---
ID: 019c1896-9d87-7f52-8e02-71cbec4e4202
```

The header is updated automatically after a successful run.

## Conversation Markers
Each run appends:

```
Time: 2026-02-01 10:44:25
--- Codex Run ---

```Markdown
<assistant response>
```

```text
<errors, if any>
```

--- Next Prompt ---
Time: 2026-02-01 10:44:25
```

Write your next prompt below the `--- Next Prompt ---` marker.

## How It Works
- If the file has a valid session ID, the next prompt is sent as a resume.
- If no session ID exists (or resume fails), the full thread is sent.
- After a successful run, the session ID is inserted or replaced at the top.
- A floating live buffer grabs focus and streams assistant output while Codex runs.
- The window title shows elapsed time and the model once detected.
- The live buffer closes on success and stays open on errors.

## Getting Started
1) Create a thread file under `.ai/threads/`.
2) Write a prompt under the `--- Next Prompt ---` marker.
3) Run `:CodexRun` or press `<leader>ac`.
4) Review the appended response and continue writing below the next prompt marker.

## Notes
- This workflow assumes you keep each thread file focused on a single topic.
- Session IDs are per thread file. There is no global session index.

## Files
- `nvim/lua/custom/codex/init.lua` - Neovim command and thread logic.
