local workspaces = {
  { id = 1, name = "home" },
  { id = 6, name = "terminal" },
  { id = 10, name = "editor" },
  { id = 11, name = "music" },
  { id = 12, name = "chatgpt" },
  { id = 13, name = "obsidian" },
  { id = 14, name = "discord" },
  { id = 15, name = "git" },
}

for _, workspace in ipairs(workspaces) do
  o.exec_on_start("hyprctl dispatch renameworkspace " .. workspace.id .. " " .. workspace.name)
end
