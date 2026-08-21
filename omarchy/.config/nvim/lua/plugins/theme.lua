local theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")

local fallback_theme = {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			flavour = "mocha",
			transparent_background = true,
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},
}

local function warn(message)
	vim.schedule(function()
		vim.notify(message, vim.log.levels.WARN)
	end)
end

local theme = fallback_theme

if vim.fn.filereadable(theme_file) == 1 then
	local ok, omarchy_theme = pcall(dofile, theme_file)
	if ok and type(omarchy_theme) == "table" then
		theme = omarchy_theme
	elseif not ok then
		warn("Could not load Omarchy Neovim theme; using Catppuccin Mocha: " .. omarchy_theme)
	else
		warn("Omarchy Neovim theme did not return a plugin spec; using Catppuccin Mocha: " .. theme_file)
	end
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
