local home = os.getenv("HOME") or ""
local user_bin = home .. "/.local/bin/"
local tts_control = home .. "/.config/nvim/scripts/nvim-tts-control media-toggle"
local centered_window_width_ratio = 0.6
local centered_window_height_ratio = 0.98

o.window("^com\\.mitchellh\\.ghostty$", {
  float = true,
  center = true,
  size = {
    "monitor_w * " .. centered_window_width_ratio,
    "monitor_h * " .. centered_window_height_ratio,
  },
})

local function center_active_window()
  local window = hl.get_active_window()
  if not window or not window.monitor then
    return
  end

  local monitor = window.monitor
  local logical_width = monitor.width / monitor.scale
  local logical_height = monitor.height / monitor.scale

  hl.dispatch(hl.dsp.window.float({ action = "set" }))
  hl.dispatch(hl.dsp.window.resize({
    x = math.floor(logical_width * centered_window_width_ratio),
    y = math.floor(logical_height * centered_window_height_ratio),
  }))
  hl.dispatch(hl.dsp.window.center())
end

local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

local function universal_paste()
  if active_window_is_terminal() then
    send_shortcut_once("SHIFT", "Insert")()
  else
    send_shortcut_once("CTRL", "V")()
  end
end

hl.unbind("SUPER + V")
hl.unbind("SUPER + CTRL + V")
hl.unbind("SUPER + G")
hl.unbind("SUPER + Z")
hl.unbind("XF86AudioPause")
hl.unbind("XF86AudioPlay")

o.bind("SUPER + V", "Clipboard history", "omarchy-shell shell toggle omarchy.clipboard")
o.bind("SUPER + CTRL + V", "Universal paste", universal_paste)

o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + D", "Discord", user_bin .. "discord.sh")
o.bind("SUPER + M", "Music", user_bin .. "youtube-music.sh")
o.bind("SUPER + E", "Editor", user_bin .. "editor-terminal.sh")
o.bind("SUPER + G", "Git", user_bin .. "git-terminal.sh")
o.bind("SUPER + N", "Notes", user_bin .. "notes-terminal.sh")
o.bind("SUPER + A", "ChatGPT", user_bin .. "chatgpt.sh")
o.bind("SUPER + H", "Home workspace", hl.dsp.focus({ workspace = "1" }))
o.bind("SUPER + I", "Terminal", user_bin .. "terminal-terminal.sh")
o.bind("SUPER + Z", "Center window", center_active_window)

o.bind("SUPER + CTRL + G", "Toggle window grouping", hl.dsp.group.toggle())

o.bind("XF86AudioPause", "Pause", tts_control, { locked = true })
o.bind("XF86AudioPlay", "Play", tts_control, { locked = true })
