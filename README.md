## ToDo Kanban

| Backlog                   | Preperation | Wip | Final inspection | Done                           |
| ------------------------- | ----------- | --- | ---------------- | ------------------------------ |
| Tesing                    |             |     |                  | Spellchecking                  |
| Breakpoints               |             |     |                  | Relative line numbers          |
| Nerd Font                 |             |     |                  | Telerscope ignore node_modules |
| LasyGit                   |             |     |                  | Tmux                           |
| Multi clipboard           |             |     |                  | Harpoon                        |
| Emojis                    |             |     |                  | Copilot                        |
| Markdown preview          |             |     |                  | Autosave                       |
| Add dependencies reademe  |             |     |                  | Printable Keyboard shortcuts   |
| Add telescope help text   |             |     |                  | Autoformatting                 |
| Install trouble? or not   |             |     |                  | 80 line ruler                  |
| TTS better voice          |             |     |                  | Center window                  |
| Fix, Harpoon autosave     |             |     |                  | Pretier                        |
| Fix, Alacrity scroll      |             |     |                  | Typescript                     |
| Obsidian note integration |             |     |                  | Linter                         |
|                           |             |     |                  | Kanban                         |
|                           |             |     |                  | Prettier                       |
|                           |             |     |                  | Prettier add html, css, yaml   |
|                           |             |     |                  | Zoom in and out                |
|                           |             |     |                  | VimBeGood                      |
|                           |             |     |                  | Telescope show hidden          |
|                           |             |     |                  | Workspace shotcuts             |
|                           |             |     |                  | Tmux styling                   |
|                           |             |     |                  | Neotree file manager           |
|                           |             |     |                  | Fix, hidden files              |
|                           |             |     |                  | Rename Repo                    |

## Install Neovim

https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-source

### Checkout spesific version

```bash
git tag
git checkout v0.9.5
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

## Rebuild hotkey cheat sheet

```bash
cd tools/hotkeyCheetSheet
npx nodemon hotKeyCheetSheet.ts
```

## Rider keybindings

Link to plugins: https://github.com/JetBrains/ideavim/wiki/IdeaVim-Plugins
Link to commands https://github.com/JetBrains/ideavim/blob/master/src/main/java/com/maddyhome/idea/vim/package-info.java
