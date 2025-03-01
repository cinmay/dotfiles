# ToDo Kanban

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
| telekasten.nvim           |             |     |                  | Typescript                     |
| Obsidian note integration |             |     |                  | Linter                         |
| Find new wallpaper        |             |     |                  | Kanban                         |
| Find Better Theme         |             |     |                  | Prettier                       |
| Show types, uses etc      |             |     |                  | Prettier add html, css, yaml   |
| Show Package size         |             |     |                  | Zoom in and out                |
| Telescope resume          |             |     |                  | VimBeGood                      |
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

https://github.com/mg979/vim-visual-multi

## Gnome Extensions

https://extensions.gnome.org/extension/545/hide-top-bar/
https://extensions.gnome.org/extension/5278/pano/

## Prerequests

```bash
 sudo apt install ripgrep alacritty tmux zsh gir1.2-gda-5.0 gir1.2-gsound-1.0 build-essential cmake gettext ninja-build unzip

```

- Install rust and cargo for htmx lsp
- Install node

## Link config files

```bash
    ln -s Documents/dotfiles/.zshrc .zshrc
    ln -s Documents/dotfiles/.tmux.conf .tmux.conf
    cd .config
    ln -s ../Documents/dotfiles/alacritty alacritty
    ln -s ../Documents/dotfiles/nvim nvim
```

## Fonts

https://www.nerdfonts.com/font-downloads

```bash
    mkdir .local/share/fonts
    cd Downloads
    unzip JetBrainsMono.zip
    mv *.ttf ~/.local/share/fonts -v
    fc-cache -f -v
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

## Rebuild hotkey cheat sheet

```bash
cd tools/hotkeyCheetSheet
npx nodemon hotKeyCheetSheet.ts
```

## Rider keybindings

Link to plugins: https://github.com/JetBrains/ideavim/wiki/IdeaVim-Plugins
Link to commands https://github.com/JetBrains/ideavim/blob/master/src/main/java/com/maddyhome/idea/vim/package-info.java
