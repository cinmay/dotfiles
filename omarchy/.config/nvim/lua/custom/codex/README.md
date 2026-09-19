# Codex in Neovim

A small Neovim client for `codex app-server`. Codex owns conversation history;
Neovim provides a read-only Markdown transcript, a separate editable prompt,
Telescope pickers, and approval dialogs. `.ai/threads/` files are no longer used
or modified. Existing Codex sessions from the old workflow remain resumable.

## Requirements

- Codex CLI installed and signed in with `codex login`.
- Neovim with `vim.system` (0.10+), Telescope, and ripgrep.
- Tested with Codex CLI **0.154.0** and Neovim **0.12.4**.

The client uses the normal Codex account, configuration, and local session store.
It starts one app-server child process lazily, communicating through stdin/stdout.
No new service, network listener, API key, or Neovim plugin is needed.
Paginated history and clarification questions opt into experimental app-server
APIs; future Codex protocol changes may require updating this client.

## Keys and commands

| Key | Command | Action |
| --- | --- | --- |
| `<leader>an` | `:CodexNew` | Start a session in Neovim's current directory |
| `<leader>ar` | `:CodexSessions` | Pick a saved session in the current directory |
| | `:CodexSessions!` | Pick from all project directories |
| | `:CodexResume <id>` | Resume a specific session |
| | `:CodexRefresh` | Reload the current session from Codex, keeping the draft |
| `<leader>as` | `:CodexSend` | Send the prompt |
| `<leader>am` | `:CodexModel` | Select model, then reasoning effort |
| `<leader>af` | `:CodexFiles` | Insert file/directory references into the prompt |
| `<leader>ap` | `:CodexApproval` | Open a pending approval or question |
| `<leader>ax` | `:CodexInterrupt` | Interrupt the running turn |

Chat uses two ordinary listed buffers in the current tab: history above an
18-line prompt. They replace the current code window. Use normal Neovim editing,
search, yanking, and `<C-w>k` / `<C-w>j` to move between the windows. Escape leaves
insert mode; there are no chat-specific Escape, Tab, or Ctrl-S mappings.
Send with **`<leader>as` in normal mode**. `:CodexRun` remains an alias for sending.
Copilot inline suggestions also work in the prompt; accept them with the
configured Copilot keymap.

The transcript keeps user and Codex messages visible and shows compact activity
lines for commands, file changes, tools, and searches. Raw command output, file
diffs, and reasoning summaries are hidden so the view stays readable like Codex
CLI.

`:q` from either chat window returns to the previous code buffer, preserving
unsaved code, the prompt draft, and your reading position. It does not cancel the
running turn.
Opening a file through Telescope, Harpoon, or `:buffer` leaves a single code
window. Closing Neovim itself still stops its app-server process.

The history winbar displays the model, reasoning effort, status, and elapsed
wall-clock time for the current/latest turn (including time awaiting approval).
Model selection applies to the next message in this session, without changing
Codex's global defaults. The list and supported effort choices come from Codex.
When Codex reports no explicit effort, the winbar says `default effort`.

## Harpoon

Use **Ctrl-H** in either chat buffer to bookmark the current conversation in your
existing Harpoon list. Files and conversations share the same list and shortcuts:
Ctrl-M opens the menu; Ctrl-A, Ctrl-R, Ctrl-S, Ctrl-T, and Ctrl-G select slots 1–5.
Conversation entries show a title and stable Codex session ID. Bookmarking history
and prompt does not create duplicate entries for the same conversation.

Selecting a conversation resumes it; selecting the already open conversation
returns to its existing view. Use `:CodexRefresh` after continuing it in another
client. Finish or interrupt a running turn before selecting a different
conversation; returning to code is always available.

Harpoon persists only the bookmark. Codex owns the history. Unsent drafts and
reading positions are kept per conversation in memory while Neovim is open.

## Files and directories

The Telescope picker lists non-ignored files (including hidden files), their
parent directories, and the project root. It excludes `.git` and respects
ripgrep's ignore rules. Empty directories are not listed. Use Tab to select
multiple entries, then Enter to append their absolute paths to the prompt.
You can edit or remove these lines before sending, or type another path directly.

These are instructions to read paths from disk, not uploads of file contents.
Unsaved editor changes are not included. Selecting a path does not grant extra
filesystem permissions or restrict Codex to only that path.

## Approvals and questions

Sessions opened here use `workspace-write`, `on-request` approval, and the user
as approval reviewer. This preserves the old integration's sandbox while letting
you answer approval requests. These settings apply to the resumed session;
global Codex configuration is not edited. Codex decides which actions require
approval; this is not a confirmation dialog for every tool call or edit.

New requests notify you and show `Response required` in the history winbar
without taking focus. Use `<leader>ap` to open the dialog. It shows the
command/network destination, requested permissions, or proposed file diffs.
The applicable choices are:

- `a`: allow once (or for the current turn for permission grants).
- `s`: allow for the session.
- `d`: decline.
- `c`: cancel the turn, for command/file approvals.
- Escape: leave the request pending and hide the dialog.

Requests queue one at a time. `<leader>ap` reopens the pending dialog. Codex
clarification questions use a choice picker or text input; cancelling input
leaves the question pending. Interrupting the turn clears its requests.
Persistent approval-rule editing and MCP elicitation forms/URL flows are not
implemented. Unsupported server requests receive an explicit error and a
notification; they are never silently approved.

## Switching between clients

Use the same machine and the same `CODEX_HOME` (normally `~/.codex`) in Neovim,
the CLI, and the desktop app's Codex integration. Finish or interrupt the turn
before switching. This client supports one selected session at a time and
sequential handoff, not simultaneous control of a running turn in another client.

- In Neovim: `<leader>ar`, `:CodexSessions!`, or `:CodexResume <id>`.
- In the CLI: `codex resume <id>`. For older non-interactive sessions, the CLI
  picker may need `codex resume --include-non-interactive --all`.
- In the desktop app: open the same local Codex session/project. Desktop filters
  may affect which sessions are visible.

The session ID and working directory are shown at the top of the transcript.
Resuming uses the session's saved directory, even when selected from another
project. New sessions use Neovim's current directory.

After using another client, explicitly resume or refresh in Neovim. This restarts
its app-server process and reloads history, avoiding stale agent context. Merely
hiding and reopening the windows keeps the existing connection and transcript.

A failed resume never creates a replacement conversation. Failed send requests
retain the draft. After a lost connection, reopen/refresh and inspect history
before retrying: the server may have accepted a prompt before disconnecting.
Exiting Neovim stops its child process; this integration is not a background
service. Unsent drafts live only in the Neovim instance.

## Configuration

```lua
require("custom.codex").setup({
  command = "codex",
  done_sound = "", -- Disable the existing mpv completion sound, if desired.
  prompt_height = 18,
})
```

## Verification

From the repository root, run the deterministic headless integration tests:

```sh
NVIM_LOG_FILE=/tmp/codex-nvim-test.log nvim --headless -u NONE -i NONE \
  -l omarchy/.config/nvim/lua/custom/codex/tests/run.lua
```

The test peer never runs a model or touches your Codex history. It exercises
fragmented/Unicode streaming, paginated and legacy history, model selection,
command/file/permission approvals, questions, stale approval callbacks,
cancellation, failed sends/resumes, process crashes, draft preservation, and the
installed Telescope pickers. It also checks native splits, `:q`, returning to
unsaved code, and real Harpoon selection, menu ordering, and bookmark persistence.
Harpoon test data uses an isolated temporary directory; your bookmarks are not
modified. Python 3 and the existing Telescope/Plenary/Harpoon installations under
Neovim's data directory are required.

Optionally validate all outgoing requests and approval responses against the
installed CLI's schema (requires Python `jsonschema`):

```sh
codex app-server generate-json-schema --out /tmp/codex-nvim-schema
CODEX_NVIM_SCHEMA=/tmp/codex-nvim-schema NVIM_LOG_FILE=/tmp/codex-nvim-test.log \
  nvim --headless -u NONE -i NONE \
  -l omarchy/.config/nvim/lua/custom/codex/tests/run.lua
```

Protocol reference: <https://developers.openai.com/codex/app-server>
