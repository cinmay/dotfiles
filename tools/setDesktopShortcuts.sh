#!/bin/bash

#Set workspace switching
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 9


##Create workspaces
gsettings set org.gnome.shell.keybindings switch-to-application-1 []
gsettings set org.gnome.shell.keybindings switch-to-application-2 []
gsettings set org.gnome.shell.keybindings switch-to-application-3 []
gsettings set org.gnome.shell.keybindings switch-to-application-4 []
gsettings set org.gnome.shell.keybindings switch-to-application-5 []
gsettings set org.gnome.shell.keybindings switch-to-application-6 []
gsettings set org.gnome.shell.keybindings switch-to-application-7 []
gsettings set org.gnome.shell.keybindings switch-to-application-8 []
gsettings set org.gnome.shell.keybindings switch-to-application-9 []


##Set switch to key
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>h']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>Comma']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>Period']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>n']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>e']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>i']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-7 "['<Super>l']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-8 "['<Super>u']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-9 "['<Super>y']"


## Set move to workspace
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Super><Shift>h']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Super><Shift>semicolon']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Super><Shift>Colon']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Super><Shift>n']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Super><Shift>e']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Super><Shift>i']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "['<Super><Shift>l']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "['<Super><Shift>u']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "['<Super><Shift>y']"

## Center window
gsettings set org.gnome.desktop.wm.keybindings move-to-center "['<Super>c']" 
