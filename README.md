# neovim-config

## ToDo Kanban

| Backlog                  | Preperation | Wip | Final inspection | Done                           |
| ------------------------ | ----------- | --- | ---------------- | ------------------------------ |
| Tesing                   |             |     |                  | Spellchecking                  |
| Breakpoints              |             |     |                  | Relative line numbers          |
| Nerd Font                |             |     |                  | Telerscope ignore node_modules |
| LasyGit                  |             |     |                  | Tmux                           |
| Multi clipboard          |             |     |                  | Harpoon                        |
| Emojis                   |             |     |                  | Copilot                        |
| Markdown preview         |             |     |                  | Autosave                       |
| Add dependencies reademe |             |     |                  | Printable Keyboard shortcuts   |
| Set default terminal     |             |     |                  | Autoformatting                 |
| Tmux styling             |             |     |                  | 80 line ruler                  |
| TTS better voice         |             |     |                  | Center window                  |
| Fix, Harpoon autosave    |             |     |                  | Pretier                        |
| Add nice start screen    |             |     |                  | Typescript                     |
| Add telescope help text  |             |     |                  | Linter                         |
| Install trouble? or not  |             |     |                  | Kanban                         |
|                          |             |     |                  | Prettier                       |
|                          |             |     |                  | Prettier add html, css, yaml   |
|                          |             |     |                  | Zoom in and out                |
|                          |             |     |                  | VimBeGood                      |
|                          |             |     |                  | Telescope show hidden          |

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
