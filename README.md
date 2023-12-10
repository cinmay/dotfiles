# neovim-config

## ToDo
* Autoformating
* Spellchecking
* Pretier
* Typescript
* Linter
* Testing
* Nerd Font
* Copilot

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
