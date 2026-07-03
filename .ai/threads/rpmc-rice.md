--- Codex Session ---
ID: 019f22ad-1911-7db0-ad16-818e7d2f1767

# rmpc rice

I want to rice rmpc music player so that it looks good and fits my needs. 

Some of the things I want is album art, a cool visualizer to add some movement and eye candy, a panel that shows the sound quality, bit rate and sample rate for both the system and the currently playing track. 

It needs to integrate well with the Omarchy themeing system. My current favorite terminal is Ghostty. 
I like a colorful futuristic look that works well on oled displays with vibrant vivid colors and deep blacks. 

Keyboard navigation is really important. There should be navigation hints on all the buttons so that I don't have to remember the shortcuts all the time.

It needs to work with the media keys. 

I currently access my music player by pressing `super + m`. Currently that opens YouTube music in it's own desktop. We need to find some way of having both YouTube Music and rmpc share the same space. 
Perhaps they can be in the same Hyperland grouped window? 
There is a scrip located at omarchy/.local/bin/youtube-music.sh  
The windows should be created when `super + m` is pressed and they are not present.

When scripting we should follow good engineering principles like yagni, Martin Fowler's Rule of three etc. 

Let's have a discussion about this before we start coding. Also if you have any clarifying questions or suggestions please let me know.


Time: 2026-07-02 13:56:21
--- Codex Run ---

Codex output:
I’ll use the Omarchy skill here because this touches Hyprland/window behavior, media keys, terminal choices, and theme integration. I’ll keep this to discovery and design discussion before any edits.
I’m going to inspect the existing dotfiles for the current `super+m` flow, Ghostty settings, and any rmpc/mpd config. That gives us a concrete design discussion instead of guessing about how your current setup launches music.
The repo already has MPD config, Ghostty config, Hyprland bindings/window config, and the YouTube Music launcher. I’m reading those now to see whether this is a small integration around existing pieces or whether rmpc needs a new config surface.
Current `super+m` is simple: it focuses a YouTube Music window by title, otherwise jumps to workspace 11 and launches the webapp. Media keys are sourced from Omarchy defaults already, so the main question is whether they should control only MPD/rmpc, only YouTube Music, or “whatever player is active” through MPRIS/playerctl.
rmpc’s current docs line up well with your target: Ghostty is listed under the Kitty album-art backend, rmpc has first-class Cava visualizer support, and it can display track bitrate/sample rate/bit depth/channels as properties. The one likely mismatch is “system audio quality”: that probably needs a small external PipeWire/MPD status surface unless we accept showing only the track/MPD side inside rmpc.
On this machine, `rmpc`, `cava`, `mpd`, `mpc`, `playerctl`, `ghostty`, `chromium`, `hyprctl`, and `jq` are installed. I don’t see `mpDris2` or `mpd-mpris`, which matters because playerctl/media keys need an MPRIS bridge if they should control MPD cleanly.
There is no rmpc config currently tracked in the repo or under `~/.config/rmpc`, so this can be added cleanly instead of untangling an existing rice. MPD is configured in the repo, but my sandboxed `mpc status` call hit `Operation not permitted`, so runtime verification of playback will need to be done from the live desktop session later.
rmpc is `0.11.0`, matching the current stable docs I checked. The default theme already includes visible shortcut labels for playback modifiers (`z/x/c/v`) and input buffer; we can extend that idea instead of inventing a separate hint system.
One practical note: `rmpc debuginfo` resolved album art to the block fallback in this non-interactive shell, even though docs list Ghostty as Kitty-compatible. I’d design the config to force/allow Kitty in Ghostty, then verify in the real launched terminal before falling back to `ueberzugpp` or block art.
No coding yet. I checked the current setup and rmpc docs.

My recommended shape:

1. Add a tracked rmpc config under `omarchy/.config/rmpc/`.
2. Launch rmpc in Ghostty from `super+m`, alongside YouTube Music on workspace 11.
3. Start with both windows on the same `music` workspace, probably tiled first. Hyprland grouping is possible, but it is more stateful and brittle because both apps launch asynchronously.
4. Keep media keys on `playerctl`, but add an MPD MPRIS bridge such as `mpd-mpris` or `mpDris2` so the existing Omarchy media key flow can control MPD/rmpc too.
5. Add a Cava FIFO output to MPD for the visualizer.
6. Use rmpc’s native album art, Cava pane, and property panes for track bitrate/sample rate/bit depth/channels.
7. For “system quality”, use a small external PipeWire status script/panel unless you’re okay with only showing the current track’s quality inside rmpc.

Relevant findings:
- `super+m` currently runs [youtube-music.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/youtube-music.sh:1), which only focuses/launches YouTube Music.
- MPD config already exists at [mpd.conf](/home/cinmay/Documents/dotfiles/omarchy/.config/mpd/mpd.conf:1).
- media keys already go through Omarchy/playerctl defaults.
- rmpc `0.11.0`, `cava`, `mpd`, `mpc`, `playerctl`, `ghostty`, and `chromium` are installed.
- No rmpc config is currently tracked or present under `~/.config/rmpc`.

rmpc supports the main UI pieces: album art, Cava visualization, configurable layout/theme/keybinds, and properties like bitrate/sample rate/bits/channels. Ghostty is documented as using the Kitty image backend for album art, though I’d verify that in the real launched terminal because this shell reported a fallback backend.

Clarifying questions:

1. Do you want `super+m` to open both rmpc and YouTube Music every time if either is missing, or only open the missing one and focus whichever already exists?
2. For the shared music space, do you prefer tabbed Hyprland grouping or a visible split layout where rmpc and YouTube Music are side by side?
3. Should media keys control the currently active player, or should MPD/rmpc take priority over YouTube Music?
4. Is “system sound quality” specifically PipeWire output format, e.g. active sink sample rate/format, or just MPD output plus current track quality?

Sources checked: rmpc docs for overview/config/album art/Cava/keybinds/properties, and Hyprland docs for grouped windows/window rules.

Time: 2026-07-02 13:56:21
--- Next Prompt ---
1. Yes, open the missing one and focus whichever already exists. 
The example behavior.
Fist time, `super+m` opens both rmpc and YouTube Music, focusing on rmpc.
When `super+m` is pressed again, and both are open, it should follow the default behavior of hyperland. 
If either is closed, it should open the missing one, but keep the focus on the one that is already open.

2. One of the main principles of my workflow is to only have one window grab my attention at a time. So no splitting as this will have two windows in focus at the same time.
I prefer tabbed Hyprland grouping.
3. Media keys should follow the system default behavior of controlling the currently active player.
4. It's important to have the system sound quality displayed too. I want to see both. 

If the script becomes too complex, then we can consider writing them in Go as needed.

Let's continue with the design discussion. 

Time: 2026-07-02 14:12:40
--- Codex Run ---

Codex output:
Given your answers, the launcher should treat music as a tabbed workspace container, not a split view. I’m checking the exact launcher controls available so the design can give rmpc a stable title/class and let the Hyprland script find/group it predictably.
The group lifecycle is still shell-sized if we keep it declarative: stable window identity, bounded waits, and explicit focus restoration. I’d only move this to Go if Chromium’s app identity or PipeWire status parsing forces us into event-driven state tracking.
The system-quality requirement changes the cleanest UI design: rmpc itself can show track quality, but not arbitrary live PipeWire output as a native pane. A dedicated Ghostty+tmux wrapper is worth considering because tmux can display a live status line without adding a split window or second visible pane.
tmux is installed (`3.6b`) and the repo tracks a top-level `.tmux.conf`, but there doesn’t appear to be existing status-line customization. That gives us room to make a dedicated music tmux config instead of disturbing your general tmux workflow.
**Design Direction**

No code yet. Your answers point to a “music group” design:

- `super+m` should become a music launcher, not just a YouTube Music launcher.
- First press: open rmpc and YouTube Music on workspace 11, group them, focus rmpc.
- Later presses when both exist: only switch to workspace 11 and let Hyprland preserve the current group tab/focus.
- If one is missing: launch the missing one into the group, then refocus the window that already existed.

I’d keep this in shell first. With `hyprctl -j clients`, `jq`, stable Ghostty class/title, and bounded waits, this is not Go-worthy yet.

**Grouping**

For rmpc, Ghostty can be launched with a stable class/title, for example a dedicated `com.cinmay.rmpc` app id. YouTube Music is trickier because Chromium webapp identity can vary; I’d try passing a stable Chromium `--class` through `omarchy-launch-webapp`, then verify with `hyprctl clients`. If Chromium ignores it, we fall back to title matching.

The group rule to test is:

- rmpc opens as the initial locked group.
- YouTube Music opens by invading that group.
- The launcher restores focus according to the state rules above.

Hyprland’s current docs support grouped/tabbed windows, `lockactivegroup`, `changegroupactive`, and group window rule options like `new lock` and `invade`.

**rmpc UI**

Inside rmpc, I’d build the main screen around:

- large album art
- Cava visualizer
- queue/current track
- track-quality panel: bitrate, sample rate, bit depth, channels
- persistent hint/footer row: `? help`, `j/k move`, `enter play/open`, `/ search`, `1-7 tabs`, `p pause`, `>/< prev/next`, `z/x/c/v modes`

This fits rmpc’s native model well. rmpc supports album art, Cava, configurable panes/layout, keybinds, and status/song properties for bitrate/sample rate/bits/channels.

**System Quality**

This is the one part I would not force into rmpc itself. rmpc can show track quality, but it does not appear to support arbitrary live PipeWire command output as a native pane.

Best fit for your “one visible window” principle: launch rmpc inside a dedicated Ghostty+tmux wrapper and use the tmux status line for live system audio quality. That gives you:

- one Hyprland window
- no split view
- rmpc still owns the main screen
- a tiny live status strip for PipeWire output format/sample rate
- no changes to your normal `.tmux.conf` if we use a dedicated music tmux config

tmux is installed, and rmpc docs list Ghostty/Kitty album art as tmux-compatible, but we should verify album art in the live terminal.

**Media Keys**

Leave Omarchy’s media-key bindings alone. They already use `playerctl` through SwayOSD. To make MPD/rmpc participate in the system default “current active player” behavior, we should add an MPD MPRIS bridge like `mpd-mpris` or `mpDris2`, then let `playerctl` decide.

Sources: rmpc overview/config docs, rmpc album art docs, rmpc Cava docs, rmpc properties docs, Hyprland dispatchers/window-rules docs.

Time: 2026-07-02 14:12:40
--- Next Prompt ---

Perhaps `mpd-mpris` is best? I don't want to install anything via the aur. I don't know if the supply chain attack on the aur is still a concern? 
It would be nice to have the system quality displayed rmpc, but tmux is an ok workaround. Can we create custom panes in rmpc for system quality? 

Time: 2026-07-02 14:38:04
--- Codex Run ---

Codex output:
I’m going to check the local Arch package database first for `mpd-mpris`/`mpDris2`. That’s better than guessing, and it lets us avoid AUR unless there is no official package path.
The local package database shows `mpd-mpris` is already in Arch `extra`, version `0.4.3-1`; `mpDris2` did not show up as an official package here. That means we can avoid AUR for the MPRIS bridge.
For AUR risk: this specific dependency does not require AUR, so we can make the conservative call and stay in signed official repos. I’m also checking rmpc’s exposed config surface rather than assuming it can host arbitrary custom data panes.
rmpc has remote/status messaging and song-change hooks, which gives us a small in-rmpc workaround path: we may be able to push system quality into rmpc’s status bar periodically. That is not a true custom pane, but it is closer to your ideal than tmux if it behaves well.
There is an rmpc companion daemon, `rmpcd`, with MPRIS/plugin support, but upstream labels it early-stage and not ready for daily use. For your setup, that argues against using it as the foundation unless we later decide to build a deeper custom integration.
Yes, `mpd-mpris` looks like the right choice.

It is in Arch `extra` as `mpd-mpris 0.4.3-1`, signed, maintained, and does not require AUR. `mpDris2` did not show up in the official package DB here. So for this setup I’d avoid AUR completely and use:

```bash
omarchy pkg add mpd-mpris
```

AUR supply-chain risk is still worth respecting in general. I would not treat AUR as forbidden, but I would avoid it when an official repo package exists. Here, we have a clean official option.

On custom rmpc panes: not really in the “run arbitrary command and render it as a pane” sense. rmpc can compose built-in panes and property components, and it can show MPD/rmpc data like bitrate/sample rate. It also has hooks and `rmpc remote status`, but I don’t see a documented native custom pane API for live external PipeWire data.

So the practical options are:

1. **Native rmpc panel for track quality**  
   This is solid: bitrate, sample rate, bit depth, channels.

2. **In-rmpc status message for system quality**  
   A small script can periodically run `rmpc remote status "SYS 48kHz / 24-bit / PipeWire"` with a timeout. This keeps the information inside rmpc, but it may compete with real rmpc status/error messages.

3. **tmux status-line workaround**  
   More robust and visually stable. It is not a custom rmpc pane, but it preserves the one-window principle and avoids splits.

4. **Patch rmpc / use rmpcd later**  
   rmpcd has plugin and MPRIS ideas, but upstream marks it early-stage/not ready for daily use, and it is not packaged here. I would not make it the base of this rice yet.

My recommendation: first try `rmpc remote status` for system quality. If it feels noisy or unreliable, fall back to a dedicated tmux status line. Sources checked: Arch package page for `mpd-mpris`, rmpc README/docs, and rmpcd README.

Time: 2026-07-02 14:38:04
--- Next Prompt ---
Let's go with tmux for the system quality display.
I have installed `mpd-mpris` 


Time: 2026-07-02 15:01:59
--- Codex Run ---

Codex output:
I’ll use the Omarchy skill again because this still affects the terminal/music workspace integration and user config. I’ll verify the installed `mpd-mpris` service shape before locking in the implementation plan.
I’ll keep this as design verification for now. The useful checks are: what `mpd-mpris` installed, whether it ships a user service, and how we can launch the rmpc/tmux wrapper without touching your normal tmux workflow.
`mpd-mpris` is installed from Arch `extra` and includes a user systemd unit at `/usr/lib/systemd/user/mpd-mpris.service`. That means the media-key integration can be a normal user service, not a custom long-running script.
I’m going to prototype rmpc config parsing in `/tmp` before adding dotfiles. rmpc’s config format is RON and I want to know whether it accepts partial configs or needs a full default-shaped file.
rmpc accepts partial config/theme files and merges them with defaults. That keeps this maintainable: we can add only the layout/theme pieces we own instead of copying the entire generated default.
The binary exposes `Pane(Cava)` plus status/song properties for bits, channels, and sample rate, so we can keep the rmpc side declarative. I’m testing the exact RON spellings before writing the repo files.
`Pane(Cava)` parses cleanly. Next I’m checking the exact property names for the track-quality panel so validation catches typos before edits.
Track-quality properties parse as `Status(Bitrate)`, `Status(SampleRate)`, `Status(Bits)`, and `Status(Channels)`. I’ll force the album art backend only if rmpc accepts that config cleanly; otherwise I’ll leave it on auto.
To avoid a brittle full-theme fork, I’m keeping the rmpc theme as a small color/style overlay and putting the persistent hint row inside the custom Queue tab layout. That gives you visible hints without replacing rmpc’s entire default layout/component tree.
I’ve got enough to start implementing the first pass: rmpc config/theme, tmux status quality line, launcher behavior, and mpd-mpris integration checks. I’ll keep the changes local to the dotfiles repo and avoid touching Omarchy source files.
I’m going to add a small `.config/rmpc` surface, a generated Omarchy-aware rmpc/tmux theme cache, and a couple of focused scripts under `.local/bin`. The existing `youtube-music.sh` will become the music workspace launcher so the current `super+m` binding keeps working.
For the launcher, I’m keeping the current `super+m` path and making it state-based: both missing opens both and focuses rmpc, both present only switches to workspace 11, and one missing launches the missing one while restoring focus to the existing one.
I’ll also add a Hyprland autostart line to start the installed `mpd-mpris.service` in the user session. It’s idempotent, uses the packaged service, and keeps the existing Omarchy media-key bindings unchanged.
The first patch hit a missing `omarchy/.config/hypr/autostart.conf`; Hyprland sources it, but it is not currently tracked. I’ll add that file instead of updating it.
No files were written by the failed patch, so I’m applying the same scoped changes again with `autostart.conf` added as a new file.
The files are in place. I’m setting executable bits on the scripts/hooks, then I’ll validate rmpc parsing, generated theme output, and shell syntax.
Validation found one rmpc RON issue: `SampleRate` is a tuple-style property and needs parentheses in this context. I’m fixing that and then I’ll rerun validation.
The theme sync parser hit an awk portability issue: `index` is a built-in name, so using it as an awk variable fails. I’ll rename that variable and revalidate generated themes.
The rmpc config now parses and resolves the album-art backend as Kitty. The theme generator writes both cache files correctly; I’m doing one more combined parse using the generated theme path.
One more rmpc detail: `--theme` is not reflected by `debuginfo` unless the config itself names the theme path. I’m making the generated cache theme the explicit config theme and letting the wrapper ensure that cache file exists before rmpc starts.
The config now explicitly points at the generated rmpc theme cache, and the wrapper copies the fallback theme there if generation fails. I’m running the final static validations now.
Static checks passed: shell syntax, rmpc config/theme parsing, and whitespace diff check are clean. Runtime checks that need the real desktop session are next; Hyprland/PipeWire access is restricted from this sandbox, so I expect some of these to report connection errors rather than real status.
The live-session checks were blocked as expected: Hyprland, user systemd, playerctl, and PipeWire all need the real session bus/socket. I’m checking whether the new dotfiles are already visible through the existing stow layout or whether `stow` will be needed to link the newly added files.
There is an existing unmanaged `~/.config/hypr/autostart.conf` that is not a stow symlink, so adding a tracked autostart file would create a stow conflict. I’m removing that repo file and will leave `mpd-mpris` enablement as a live-session step instead.
Because the new helper scripts are not yet stowed into `~/.local/bin`, I’m making the launcher resolve helper paths relative to the real dotfiles script path. That way the existing `youtube-music.sh` symlink can call the new helpers immediately, while still working normally after stow.
The helper path resolution now works from the existing stowed `youtube-music.sh` symlink, even before the new helper files are stowed. I’m reviewing the resulting diff and outstanding live-session limitations before wrapping up.
The tracked diff still includes pre-existing unrelated changes in `monitors.conf` and MPD state, plus untracked `.ai/.codex` files. I’m not touching those; the music changes are confined to the launcher, new rmpc config, and new helper scripts.
One optional static check remains: if `shellcheck` is installed, I’ll run it over the shell scripts. If it isn’t present, the `bash -n` syntax check is the shell validation we have.
`shellcheck` is not installed, so validation is `bash -n`, rmpc parse checks, theme generation checks, and `git diff --check`. I’m marking the work complete with the runtime caveats called out.
Implemented the first pass.

Added rmpc config/theme and tmux support:
- [config.ron](/home/cinmay/Documents/dotfiles/omarchy/.config/rmpc/config.ron:1)
- [theme.ron](/home/cinmay/Documents/dotfiles/omarchy/.config/rmpc/theme.ron:1)
- [tmux.conf](/home/cinmay/Documents/dotfiles/omarchy/.config/rmpc/tmux.conf:1)

Added helpers:
- [rmpc-theme-sync.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/rmpc-theme-sync.sh:1) generates rmpc/tmux colors from the current Omarchy Ghostty theme.
- [music-system-quality.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/music-system-quality.sh:1) prints the system sink format for the tmux status line.
- [rmpc-music-session.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/rmpc-music-session.sh:1) launches rmpc inside an isolated `tmux -L rmpc-music` session.
- [theme-set](/home/cinmay/Documents/dotfiles/omarchy/.config/omarchy/hooks/theme-set:1) refreshes rmpc theme on Omarchy theme changes once stowed.

Updated [youtube-music.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/youtube-music.sh:1) so `super+m` now manages the music group:
- none open: opens rmpc + YouTube Music, focuses rmpc
- both open: switches to workspace 11 only
- one missing: opens the missing one, restores focus to the existing one

Validation done:
- `bash -n` passed for all scripts/hooks
- rmpc config/theme parse passed
- generated Omarchy theme/tmux files correctly
- `git diff --check` passed
- `shellcheck` is not installed

Runtime checks blocked by sandbox session access:
- `hyprctl reload/configerrors` could not connect to Hyprland
- `systemctl --user --now enable mpd-mpris.service` could not connect to the user bus
- `playerctl`/PipeWire checks were blocked

Run this once in the live desktop session for `mpd-mpris`:

```bash
systemctl --user --now enable mpd-mpris.service
```

Then press `super+m` and verify grouping/title matching. I used current Hyprland dispatcher/window-rule docs for the group syntax: https://github.com/hyprwm/hyprland-wiki/blob/main/content/Configuring/Dispatchers.md and https://github.com/hyprwm/hyprland-wiki/blob/main/content/Configuring/Window-Rules.md.

text
2026-07-02T12:54:14.849330Z ERROR codex_core::tools::router: error=apply_patch verification failed: Failed to read file to update /home/cinmay/Documents/dotfiles/omarchy/.config/hypr/autostart.conf: No such file or directory (os error 2)

Time: 2026-07-02 15:01:59
--- Next Prompt ---

I ran stow to update the dotfiles and rebooted the computer.

When I use `super+m` it takes about 10 seconds for YouTube Music to open. It is not opening as a group. When I leave and come back to the workspace, it opens a group.
I don't think the terminal with rmpc is opening at all. 

When I try to open rmpc directly, I get the following error:

```Bash
dotfiles git:(main) ✗ rmpc
Error: Failed to read config
Caused by:
  Theme file not found at any of the possible paths
Using the default values
```


Time: 2026-07-03 11:45:17
--- Codex Run ---

Codex output:
I’ll use the Omarchy skill again because this is Hyprland/window grouping plus terminal/theme config. The immediate issue is clear: direct `rmpc` points at a generated cache theme that does not exist yet; I’ll fix that first, then simplify the launcher/group behavior.
I’m checking the live/stowed paths now, not just the repo copies. The symptoms suggest two separate problems: the generated theme path is too eager, and the launch rules wait on YouTube Music too long before rmpc is visible.
The missing rmpc window is likely a downstream effect of the theme error: rmpc exits, the launcher waits for it for several seconds, then YouTube Music launches late. I’m changing the config to use the checked-in theme for direct `rmpc`, and I’ll stop the launcher from blocking YouTube Music behind the rmpc wait.
The rmpc config now points at the stowed static theme, so direct `rmpc` should no longer depend on a cache file. I’m validating that parse path and the launcher syntax now.
Direct `rmpc` now resolves the theme correctly. The full `git diff --check` is blocked by trailing whitespace in an unrelated `.ai/threads/rpmc-rice.md` file, so I’m checking only the files changed for this fix.
I’m not adding permanent Hyprland window rules yet. The current failure can be explained by rmpc exiting before its window exists, which also made the launcher wait before opening YouTube Music. I want to avoid piling on extra rules until this simpler fix is tested.
The sandbox cannot write `~/.cache/rmpc`, but that is expected here; the live desktop session will be able to. Direct `rmpc` no longer needs that cache, and the wrapper will still generate it for the tmux status/theme path at launch.
Fixed the immediate issues.

What changed:
- [config.ron](/home/cinmay/Documents/dotfiles/omarchy/.config/rmpc/config.ron:5) now points direct `rmpc` at the stowed static theme: `~/.config/rmpc/theme.ron`. That removes the missing `~/.cache/rmpc/theme.ron` error.
- [youtube-music.sh](/home/cinmay/Documents/dotfiles/omarchy/.local/bin/youtube-music.sh:121) no longer waits for rmpc before launching YouTube Music. It launches rmpc, waits `0.2s`, launches YouTube Music, then focuses rmpc if it appears.

Validated:
- `rmpc debuginfo` now resolves the theme path correctly.
- `bash -n` passes.
- `git diff --check` passes for the touched files.

You should be able to test immediately since `~/.config/rmpc/config.ron` and `~/.local/bin/youtube-music.sh` are stowed symlinks.

Please try:
```bash
rmpc
```

Then press `super+m`.

If grouping is still delayed or wrong after rmpc now opens, the next thing to inspect is the actual live window identity from Hyprland, because the sandbox cannot access your Hyprland socket:

```bash
hyprctl -j clients | jq '.[] | {class, initialClass, title, workspace, grouped}'
```

I checked the current Hyprland group rule docs; `new lock` and `invade` are still valid group options.

Time: 2026-07-03 11:45:17
--- Next Prompt ---

Now, YouTube Music opens immediately. 

Rmpc is still not opening. When I try to open it directly, I get the following error:
```Bash
dotfiles git:(main) ✗ rmpc
Error: Failed to read config
Caused by:
  Deserialization error, scrollbar: Unexpected missing field named `symbols` in `ScrollbarConfigFile`
Using the default values
```

