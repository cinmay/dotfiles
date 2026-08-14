--- Codex Session ---
ID: 019c7f6e-1bc6-7cf2-962d-e0cde69c7ea6



# Control window size and position

Lets have a discussion about how to control the size and position of windows in my Omarchy setup. 
I want my terminal to be centered and not take up the whole screen. But I want other windows to be able to take up the full screen if I want them to.
I want a hotkey to toggle a window to take up the full size but not the traditional full screen mode. Just maximized within the current workspace.
At the moment, hyperland is set up to if there is only one window, it will be centered and take up a portion of the screen. This isn't working out. 
Let's discuss how we can adjust the configuration to achieve the desired behavior.



Time: 2026-02-21 10:02:44
--- Codex Run ---

```Markdown
What you’re seeing (single window centered and smaller) is coming from a local override in your repo:

- `omarchy/.config/hypr/looknfeel.conf` has `dwindle { single_window_aspect_ratio = 1 1 }`, which forces *all* single tiled windows to keep a narrower aspect ratio. That’s why one window doesn’t fill the workspace.

**Direction to hit your goal**
- Remove or comment that `single_window_aspect_ratio` line so single tiled windows can fill the workspace.
- Then explicitly make *terminals* float, size, and center via window rules. That keeps your terminal centered without forcing all apps into the “single-window shrink” behavior.

**Good news on the “maximize (not fullscreen)” hotkey**
- Omarchy already includes this in the default bindings:
  - `SUPER + CTRL + F` → `fullscreenstate, 0 2` labeled “Tiled full screen”
  - This is the “maximize within workspace” behavior you want (i.e., not traditional fullscreen). It’s in `~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf`.

If you want to make this more explicit in *your* config, we can rebind it in `omarchy/.config/hypr/bindings.conf`.

**Proposed local overrides (if you want me to implement)**
1) Remove single-window shrinking:
   - `omarchy/.config/hypr/looknfeel.conf` → comment out the `single_window_aspect_ratio` line.

2) Add terminal-only float/center/size rules:
   - Add a `omarchy/.config/hypr/windows.conf` and source it from `omarchy/.config/hypr/hyprland.conf`.
   - Use the terminal tag already defined by Omarchy (`tag +terminal` in default `apps/terminals.conf`).

Example rules (adjust size to taste):
```ini
# ~/.config/hypr/windows.conf
windowrule = float on, match:tag terminal
windowrule = center on, match:tag terminal
windowrule = size 1200 800, match:tag terminal
```

That gives:
- Terminal: centered + fixed size
- Everything else: can tile and maximize to full workspace
- You still have `SUPER+CTRL+F` for “maximize (not fullscreen)”

If you want me to implement this, tell me:
1) Which terminal class you actually use (Alacritty/Ghostty/Kitty)?  
2) Preferred terminal size (e.g., 1200x800 or % of screen)?  
3) Do you want a new hotkey for tiled-maximize, or keep `SUPER+CTRL+F`?


Time: 2026-02-21 10:02:44
--- Next Prompt ---
1. I use Ghostty as my terminal.
2. I use different monitors, so a fixec size isn't going to work.
3. Let's wait a bit on the hotkey, I want to see how the changes to the window rules work first.

Time: 2026-02-21 10:25:09
--- Codex Run ---

Made the terminal behavior local and monitor-relative, and removed the single-window shrink that was affecting all apps.

Changes:
- Added `~/.config/hypr/windows.conf` and sourced it from `omarchy/.config/hypr/hyprland.conf` to apply terminal-only float/center/size rules.
- Commented out `single_window_aspect_ratio` in `omarchy/.config/hypr/looknfeel.conf` so single tiled windows can fill the workspace again.

Files:
- `omarchy/.config/hypr/hyprland.conf`
- `omarchy/.config/hypr/looknfeel.conf`
- `omarchy/.config/hypr/windows.conf`

Next steps (pick one):
1) Reload Hyprland config (e.g., `hyprctl reload`) and open a terminal to confirm it floats and centers at ~70% of the monitor.
2) If the size feels off, tell me your preferred percentage and I’ll tune `monitor_w*0.7` / `monitor_h*0.7`.
3) If you want terminal tiled by default but a hotkey to float+center, we can do that too.

Time: 2026-02-21 10:25:09
--- Next Prompt ---
I get an error in /home/cinmay/Documents/dotfiles/omarchy/.config/hypr/hyprland.conf: line 20: source= globbing error: found no matches 
2. Sure, let's go with 70% for now and we can adjust later if needed.
3. Let's wait with the hotkey for now, I want to see how the changes to the window rules work first.

Time: 2026-02-21 10:31:41
--- Codex Run ---

```Markdown
That error is because Hyprland can’t find `~/.config/hypr/windows.conf` in your live config, even though it exists in the repo. It treats missing `source` files as a globbing failure.

To fix it, re‑stow so the new file is linked into `~/.config/hypr/`:

- Run `stow -t "$HOME" omarchy`

After that, Hyprland should pick up `~/.config/hypr/windows.conf` and the error will disappear.

The 70% sizing is already in place in `omarchy/.config/hypr/windows.conf`, so once the file is linked it should center Ghostty at ~70% of the monitor.

If you want me to change the percentage later, just tell me the new value.
```

Time: 2026-02-21 10:31:41
--- Next Prompt ---


