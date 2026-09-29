# Claude in Neovim

A small Neovim client for Claude Code's headless mode (`claude -p` with
`stream-json` input and output, the protocol the Agent SDK uses). Claude Code
owns the conversation and its settings; Neovim provides a read-only Markdown
history, a separate editable prompt, and answers Claude's questions and
permission requests in place of the prompt.

It is a sibling of `custom/codex`, not a shared abstraction: the window handling
is deliberately the same, the protocol handling is Claude's own.

## Requirements

- Claude Code installed and signed in (`claude` works in a terminal).
- Neovim with `vim.system` (0.10+).
- Tested with Claude Code **2.1.283** and Neovim **0.12.5**.

Each chat runs one `claude` child process in Neovim's current directory,
talking JSON lines over stdin/stdout. It loads your normal Claude Code setup:
settings, `CLAUDE.md`, skills, plugins, and connectors.

## Keys and commands

| Key | Command | Action |
| --- | --- | --- |
| `<leader>ana` | `:ClaudeNew` | Start a chat in Neovim's current directory |
| `<leader>ara` | `:ClaudeSessions` | Pick a saved session in the current directory |
| | `:ClaudeSessions!` | Pick from all project directories |
| | `:ClaudeResume <id>` | Resume a specific session |
| `<leader>as` | `:ClaudeSend` | Send the prompt |
| `<leader>am` | `:ClaudeModel` | Change model, effort, or permission mode |
| `<leader>ax` | `:ClaudeInterrupt` | Interrupt the running turn |

`<leader>ana` and `<leader>ara` work everywhere (`a` for Anthropic; Codex uses
`o`). The other keys exist only in the chat buffers, so they cannot fire from
code.

The layout matches Codex: history above an 18-line prompt, replacing the current
code window. Use normal Neovim editing, search, yanking, and read-aloud
(`gs{motion}`) in both. `:q` from either window returns to the code buffer,
keeping the draft and reading position, without stopping the running turn.
Opening a file through Telescope, Harpoon, or `:buffer` leaves a single code
window. Open `claude://prompt` or `claude://history` from the buffer list to
return to the chat.

The history shows your prompts, Claude's replies, plans, one activity line per
tool call (`• Bash git status · done`), and notices from Claude Code (for
example a safety fallback to another model). Thinking, tool output, and
subagent messages are hidden.

The winbar shows the model Claude reports, the effort, the permission mode, the
status, the elapsed time of the latest turn, how full the context window is
(`ctx 3%`, or `ctx 31k` until the window size is known), and the five-hour
usage limit (`5h 12%`). Claude does not report the effort it starts with, so the
winbar says `default effort` until you choose one or resume a session that
recorded it.

`<leader>am` opens one menu for the settings a session can change. Changes
apply to this chat only; Claude Code's settings files are not edited:

- **Model**, from the list Claude Code offers.
- **Effort**, from the levels the current model supports.
- **Permission mode**: Manual, Accept edits, Plan, Auto, or Don't ask. Bypass is
  not offered because Claude Code only allows it when launched with a flag.

## Permissions, questions, and plans

Neovim passes no permission flags: the chat starts in the mode set in Claude
Code's settings (`permissions.defaultMode` in `~/.claude/settings.json`). In
`auto` mode Claude rarely asks, so a request takes over the prompt window
instead of waiting in a notification:

- **Questions** show one at a time. Press the option's number; `Other` asks for
  free text. For multi-select questions, numbers toggle options and Enter
  submits.
- **Plans** are shown in full and also kept in the history. `1` approves and
  Claude starts; `2` keeps planning, then send your feedback as a normal prompt.
- **Permission requests** show the tool and its command or file. `1` allows
  once, `2` denies. There is no "always allow": in the recorded protocol it did
  not stop Claude asking again, and `auto` mode makes it rarely needed.

Your draft stays in the prompt buffer and returns once you answer. `:q` leaves a
request waiting. If a request arrives while the chat is hidden, you get a
desktop notification (`notify-send`) and the request is waiting in the prompt
window when you open the chat. Unsupported control requests are rejected with
an error and a notification, never silently allowed.

## Sessions, drafts, and Harpoon

Claude Code owns the history. `<leader>ara` lists the sessions saved for the
current directory, newest first, titled with Claude's generated title or the
first prompt. Sessions that were opened but never used are skipped. Resuming loads the history
from Claude Code's session file and starts `claude --resume` in the session's own
directory, so a session picked with `:ClaudeSessions!` keeps working in its
project. The history shows the conversation as the CLI does: turns abandoned by
a rewind, slash-command echoes, and "while you were away" recaps are left out.

Resuming is refused, leaving the current chat untouched, when the session is not
found, its directory no longer exists, or another live Claude process (the CLI in
a terminal, for example) has it open. Finish there first; to continue a Neovim
chat in the CLI, use `claude --resume <id>` with the session ID shown at the top
of the history.

Unsent drafts and reading positions are kept per conversation while Neovim is
open. A draft typed in a new, unsent chat comes back with `<leader>ana`.

Use **Ctrl-H** in either chat buffer to bookmark the conversation in your Harpoon
list (after the first message). Claude conversations appear as
`Claude: <title> [claude://<id>]` next to files and Codex conversations, and
selecting one resumes it, or returns to it if it is already open.

The session files and the running-process registry (`~/.claude/projects/` and
`~/.claude/sessions/`, or under `CLAUDE_CONFIG_DIR`) are internal to Claude Code.
Their use is limited to `sessions.lua`, so a format change is fixed in one place.

## Failures

If the `claude` process exits, the history shows the error and stays on screen.
Opening the chat again reconnects with `--resume` to the same session, so the
conversation continues. A prompt is cleared once it is written to Claude; after a
crash it is still in the history if you need to send it again.

## Configuration

```lua
require("custom.claude").setup({
  command = "claude",
  done_sound = "", -- Disable the completion sound shared with Codex, if desired.
  desktop_notify = "", -- Disable desktop notifications for waiting requests.
  prompt_height = 18,
})
```

## Verification

From the repository root, run the deterministic headless tests:

```sh
NVIM_LOG_FILE=/tmp/claude-nvim-test.log nvim --headless -u NONE -i NONE \
  -l omarchy/.config/nvim/lua/custom/claude/tests/run.lua
```

The fake CLI (`tests/fake_claude.py`) never runs a model or touches your Claude
sessions. Its messages follow recordings of the real protocol. It exercises
fragmented Unicode streaming, tool lines, subagent filtering, notices and model
changes, the settings menu, context and usage-limit display, questions (single
and multi-select, stale keys), plans, allowed and denied permissions, requests
arriving while hidden, interrupting, turn errors, crashes with reconnect, native
splits, and `:q`. Resume runs against a temporary session store with rewound
branches, hidden entries, a missing directory, and a session open elsewhere. It
also checks per-conversation drafts and the installed Telescope picker, and uses
real Harpoon with an isolated data directory; your sessions and bookmarks are
not touched. Python 3 and the Telescope, Plenary, and Harpoon installations under
Neovim's data directory are required.
