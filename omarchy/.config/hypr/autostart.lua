-- Keep VA-API decode on the Intel GPU that drives the hybrid laptop's display.
-- The desktop (stue-pc) has no Intel GPU, so there libva picks its own driver.
local hostname = io.open("/etc/hostname"):read("l")
if hostname == "resurrection" then
  hl.env("LIBVA_DRIVER_NAME", "iHD")
end

local workspaces = {
  { id = 1, name = "home" },
  { id = 6, name = "terminal" },
  { id = 10, name = "editor" },
  { id = 11, name = "music" },
  { id = 12, name = "agent" },
  { id = 13, name = "obsidian" },
  { id = 14, name = "discord" },
  { id = 15, name = "git" },
}

for _, workspace in ipairs(workspaces) do
  hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.workspace.rename({ workspace = tostring(workspace.id), name = workspace.name }))
  end)
end
