local theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")

local function warn(message)
	vim.schedule(function()
		vim.notify(message, vim.log.levels.WARN)
	end)
end

local ok, theme = pcall(dofile, theme_file)
if not ok then
	warn("Could not load Omarchy Neovim theme: " .. theme)
	return {}
end

if type(theme) ~= "table" then
	warn("Omarchy Neovim theme did not return a plugin spec: " .. theme_file)
	return {}
end

for _, spec in ipairs(theme) do
	if type(spec) == "table" then
		if spec[1] == "LazyVim/LazyVim" then
			spec.enabled = false
		elseif spec[1] then
			spec.lazy = false
			spec.priority = spec.priority or 1000
		end
	end
end

return theme
