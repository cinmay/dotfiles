local M = {}

local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"

function M.current_spec()
	package.loaded["plugins.theme"] = nil

	local ok, theme_spec = pcall(require, "plugins.theme")
	if ok and type(theme_spec) == "table" then
		return theme_spec
	end

	return nil
end

function M.colorscheme(theme_spec)
	for _, spec in ipairs(theme_spec or {}) do
		if type(spec) == "table" and spec[1] == "LazyVim/LazyVim" and type(spec.opts) == "table" then
			return spec.opts.colorscheme
		end
	end
end

function M.apply(theme_spec)
	local colorscheme = M.colorscheme(theme_spec or M.current_spec())
	if not colorscheme or colorscheme == "" then
		return false
	end

	pcall(function()
		require("lazy.core.loader").colorscheme(colorscheme)
	end)

	local ok = pcall(vim.cmd.colorscheme, colorscheme)
	if ok and vim.fn.filereadable(transparency_file) == 1 then
		pcall(vim.cmd.source, transparency_file)
	end

	return ok
end

return M
