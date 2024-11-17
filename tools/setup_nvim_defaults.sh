#!/bin/bash

# Script to set up nvim as the default editor, vi, and vim

echo "Setting up Neovim as the default editor, vi, and vim..."

# Ensure /usr/local/bin/nvim exists
if [[ ! -f /usr/local/bin/nvim ]]; then
  echo "Error: /usr/local/bin/nvim not found. Make sure Neovim is installed in /usr/local/bin."
  exit 1
fi

# Add nvim to update-alternatives
echo "Adding Neovim to update-alternatives..."
sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/nvim 100
sudo update-alternatives --install /usr/bin/vi vi /usr/local/bin/nvim 100
sudo update-alternatives --install /usr/bin/vim vim /usr/local/bin/nvim 100

# Configure alternatives for editor, vi, and vim
echo "Configuring Neovim as the default editor..."
sudo update-alternatives --set editor /usr/local/bin/nvim

echo "Configuring Neovim as the default vi..."
sudo update-alternatives --set vi /usr/local/bin/nvim

echo "Configuring Neovim as the default vim..."
sudo update-alternatives --set vim /usr/local/bin/nvim

# Verify the configuration
echo "Verifying the configuration..."
update-alternatives --display editor
update-alternatives --display vi
update-alternatives --display vim

echo "Neovim has been successfully set as the default editor, vi, and vim!"
