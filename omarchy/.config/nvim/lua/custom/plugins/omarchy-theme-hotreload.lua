return {
	{
		name = "theme-hotreload",
		dir = vim.fn.stdpath("config"),
		lazy = false,
		priority = 1000,
		config = function()
			local omarchy_theme = require("custom.omarchy_theme")

			local function reload_theme()
				local theme_spec = omarchy_theme.current_spec()
				if not theme_spec then
					return
				end

				local theme_plugin_name = omarchy_theme.plugin_name(theme_spec)

				-- Clear all highlight groups before applying new theme
				vim.cmd("highlight clear")
				if vim.fn.exists("syntax_on") then
					vim.cmd("syntax reset")
				end

				-- Reset background to default so colorscheme can set it properly (light themes will set to light)
				vim.o.background = "dark"

				-- Unload theme plugin modules to force full reload
				if theme_plugin_name then
					local plugin = require("lazy.core.config").plugins[theme_plugin_name]
					if plugin then
						local plugin_dir = plugin.dir .. "/lua"
						require("lazy.core.util").walkmods(plugin_dir, function(modname)
							package.loaded[modname] = nil
							package.preload[modname] = nil
						end)
					end
				end

				vim.defer_fn(function()
					if omarchy_theme.apply(theme_spec) then
						vim.cmd("redraw!")
						vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
						vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })
						vim.cmd("redraw!")
					end
				end, 5)
			end

			vim.api.nvim_create_autocmd("User", {
				pattern = "LazyReload",
				callback = function()
					vim.schedule(function()
						reload_theme()
					end)
				end,
			})

			omarchy_theme.start_watcher(function(theme_file)
				require("lazy.manage.reloader").reload({
					{ file = theme_file, what = "changed" },
				})
			end)
		end,
	},
}
