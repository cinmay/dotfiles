# ToDo Kanban

## Why
Why: The purpose of my setup is to reinforce my pursuit of personal excellence in professional software development.

## Philosophy & Guiding Principles
This setup is a deliberate professional workspace for focus and personal excellence. Everything is intentional: every tool exists for a reason, every screen element earns its place, and anything that distracts or dilutes the work is removed. The environment is built for single-tasking, with one monitor, keyboard-first navigation, and one workspace per task so attention stays on the work. I prefer hard-mode learning because mastery matters more than convenience, and a bespoke Neovim workflow forces me to understand my tools deeply. The system is designed so everything has a hotkey and a clear purpose, reinforcing discipline, flow, and craftsmanship.

Docs: [Codex thread workflow](nvim/lua/custom/codex/README.md)


| Backlog                   | Preperation | Wip | Final inspection | Done                           |
| ------------------------- | ----------- | --- | ---------------- | ------------------------------ |
| Tesing                    |             |     |                  | Spellchecking                  |
| Breakpoints               |             |     |                  | Relative line numbers          |
| Telescope resume          |             |     |                  | Telerscope ignore node_modules |
| LasyGit                   |             |     |                  | Tmux                           |
| Multi clipboard           |             |     |                  | Harpoon                        |
| Emojis                    |             |     |                  | Copilot                        |
| Show Package size         |             |     |                  | Autosave                       |
| Show types, uses etc      |             |     |                  | Printable Keyboard shortcuts   |
| Add telescope help text   |             |     |                  | Autoformatting                 |
| Install trouble? or not   |             |     |                  | 80 line ruler                  |
| TTS better voice          |             |     |                  | Center window                  |
| Fix, Harpoon autosave     |             |     |                  | Pretier                        |
| telekasten.nvim           |             |     |                  | Typescript                     |
| Obsidian note integration |             |     |                  | Linter                         |
| Find new wallpaper        |             |     |                  | Kanban                         |
| Install Neotest           |             |     |                  | Prettier                       |
|                           |             |     |                  | Prettier add html, css, yaml   |
|                           |             |     |                  | Zoom in and out                |
|                           |             |     |                  | VimBeGood                      |
|                           |             |     |                  | Telescope show hidden          |
|                           |             |     |                  | Workspace shotcuts             |
|                           |             |     |                  | Tmux styling                   |
|                           |             |     |                  | Neotree file manager           |
|                           |             |     |                  | Fix, hidden files              |
|                           |             |     |                  | Rename Repo                    |
|                           |             |     |                  | Lsp next error                 |
|                           |             |     |                  | Upgrade harpoon                |
|                           |             |     |                  | Illuminate                     |
|                           |             |     |                  | Lsp Docs                       |
|                           |             |     |                  | Fix, Alacrity scroll           |
|                           |             |     |                  | Buffer navigaton keys          |
|                           |             |     |                  | Find Better Theme              |
|                           |             |     |                  | Nerd Font                      |
|                           |             |     |                  | Markdown preview               |
|                           |             |     |                  | Add dependencies reademe       |

https://github.com/mg979/vim-visual-multi


## Bootstrap dotfiles

### Omarchy
```bash

```bash
stow -t "$HOME" omarchy
```

## Install Neovim

https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-source

### Checkout spesific version

```bash
git tag
git checkout v0.10.4
```

### Prerequisites

https://github.com/neovim/neovim/blob/master/BUILD.md#build-prerequisites
Node ( required for some plugins )

Install node

```bash
https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating
```

### Build and install

```bash
rm -r build/  # clear the CMake cache
make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim" CMAKE_BUILD_TYPE=Release -j 16
make install
export PATH="$HOME/neovim/bin:$PATH" # add to .bashrc
```

## Install Typescript

run :Mason
Use ctrl + f to search for the language you want to install

## Find keybindings

run :Verbose map <the keybinding> e.g. :Verbose map <leader>g

## Local Neovim Text To Speech

Dependencies on Arch:

```bash
sudo pacman -S mpv socat
```

Start Kokoro-FastAPI with Podman:

```bash
podman run --rm \
  --name kokoro-tts \
  -p 127.0.0.1:8880:8880 \
  -e HOST=0.0.0.0 \
  -e PORT=8880 \
  ghcr.io/remsky/kokoro-fastapi-cpu:latest
```

Test the TTS endpoint manually:

```bash
curl -s http://127.0.0.1:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kokoro",
    "voice": "af_heart",
    "input": "Hello from local text to speech in Neovim.",
    "response_format": "mp3"
  }' \
  --output /tmp/test-tts.mp3

mpv /tmp/test-tts.mp3
```

Neovim usage examples:

```text
gsiw        speak inner word
gsap        speak paragraph
gss         speak current line
3gss        speak 3 lines
visual gs   speak selection
<leader>rp  pause/resume
```

## Rider keybindings


Link to plugins: https://github.com/JetBrains/ideavim/wiki/IdeaVim-Plugins
Link to commands https://github.com/JetBrains/ideavim/blob/master/src/main/java/com/maddyhome/idea/vim/package-info.java
