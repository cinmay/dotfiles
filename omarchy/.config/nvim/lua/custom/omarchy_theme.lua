local M = {}

local theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"
local watcher
local watched_signature

local function stat_signature(path)
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return nil
	end

	return table.concat({
		stat.size or 0,
		stat.mtime and stat.mtime.sec or 0,
		stat.mtime and stat.mtime.nsec or 0,
		stat.ino or 0,
	}, ":")
end

function M.theme_file()
	return theme_file
end

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

function M.plugin_name(theme_spec)
	for _, spec in ipairs(theme_spec or {}) do
		if type(spec) == "table" and spec[1] and spec[1] ~= "LazyVim/LazyVim" then
			return spec.name or spec[1]
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

function M.start_watcher(on_change)
	if watcher then
		return
	end

	watched_signature = stat_signature(theme_file)
	watcher = assert(vim.uv.new_timer())
	watcher:start(
		2000,
		2000,
		vim.schedule_wrap(function()
			local next_signature = stat_signature(theme_file)
			if not next_signature then
				return
			end

			if watched_signature and next_signature ~= watched_signature then
				watched_signature = next_signature
				on_change(theme_file)
				return
			end

			watched_signature = next_signature
		end)
	)

	vim.api.nvim_create_autocmd("VimLeavePre", {
		once = true,
		callback = function()
			M.stop_watcher()
		end,
	})
end

function M.stop_watcher()
	if not watcher then
		return
	end

	watcher:stop()
	watcher:close()
	watcher = nil
end

return M
