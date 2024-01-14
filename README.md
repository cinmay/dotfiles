# neovim-config

## ToDo
* Autoformatting
* Pretier
* Typescript
* Linter
* Testing
* Breakepoints
* Nerd Font
* Multi clipboard
* Emojis 
* Markdown preview
* Show hidden files in telescope
* Screen reader
* Zoom in and out
* 80 line ruler
* Vim be good

## Done
* Show line numbers with git changes
* Relative line numbers
* Telescope ignore node_modules
* Tmux 
* Harpoon
* Copilot
* Autosave
* Printable Keyboard shortcuts
* Spellchecking

## Install Neovim

https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-source

### Checkout spesific version

``` bash
git tag
git checkout v0.9.4
```

### Build and install

``` bash
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


