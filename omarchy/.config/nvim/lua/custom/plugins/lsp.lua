return {
	"neovim/nvim-lspconfig",

	-- We still use mason + mason-lspconfig + mason-tool-installer
	-- to install servers and auto-enable them.
	dependencies = {
		-- Mason core
		{ "mason-org/mason.nvim", opts = {} },

		-- Automatically enable installed servers using vim.lsp.enable()
		{ "mason-org/mason-lspconfig.nvim", opts = {} },

		-- Install language servers + tools like stylua
		"WhoIsSethDaniel/mason-tool-installer.nvim",

		-- Nice status for LSP
		{ "j-hui/fidget.nvim", opts = {} },

		-- Completion capabilities (we reuse this from your existing config)
		"saghen/blink.cmp",
	},

	config = function()
		---------------------------------------------------------------------------
		-- LspAttach: keymaps, highlighting, inlay hints
		---------------------------------------------------------------------------
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if not client then
					return
				end

				local map = function(keys, func, desc, mode)
					mode = mode or "n"
					vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
				end

				-- Rename
				map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

				-- Code actions
				map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

				-- References / implementations / definitions / declarations
				local tbuiltin = require("telescope.builtin")
				map("grr", tbuiltin.lsp_references, "[G]oto [R]eferences")
				map("gri", tbuiltin.lsp_implementations, "[G]oto [I]mplementation")
				map("grd", tbuiltin.lsp_definitions, "[G]oto [D]efinition")
				map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

				-- Document + workspace symbols
				map("gO", tbuiltin.lsp_document_symbols, "Open Document Symbols")
				map("gW", tbuiltin.lsp_dynamic_workspace_symbols, "Open Workspace Symbols")

				-- Type definition
				map("grt", tbuiltin.lsp_type_definitions, "[G]oto [T]ype Definition")

				-- Helper for feature checks (0.11+ style)
				local function client_supports_method(method, bufnr)
					return client:supports_method(method, { bufnr = bufnr })
				end

				-- Document highlight support
				if client_supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
					local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })

					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.clear_references,
					})

					vim.api.nvim_create_autocmd("LspDetach", {
						group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
						callback = function(ev)
							vim.lsp.buf.clear_references()
							vim.api.nvim_clear_autocmds({
								group = "kickstart-lsp-highlight",
								buffer = ev.buf,
							})
						end,
					})
				end

				-- Inlay hints toggle if supported
				if client_supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
					map("<leader>th", function()
						vim.lsp.inlay_hint.enable(
							not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
							{ bufnr = event.buf }
						)
					end, "[T]oggle Inlay [H]ints")
				end
			end,
		})

		---------------------------------------------------------------------------
		-- Diagnostics configuration
		---------------------------------------------------------------------------
		vim.diagnostic.config({
			severity_sort = true,
			float = { border = "rounded", source = "if_many" },
			underline = { severity = vim.diagnostic.severity.ERROR },
			signs = vim.g.have_nerd_font and {
				text = {
					[vim.diagnostic.severity.ERROR] = "󰅚 ",
					[vim.diagnostic.severity.WARN] = "󰀪 ",
					[vim.diagnostic.severity.INFO] = "󰋽 ",
					[vim.diagnostic.severity.HINT] = "󰌶 ",
				},
			} or {},
			virtual_text = {
				source = "if_many",
				spacing = 2,
				format = function(diagnostic)
					-- Simple, explicit mapping keeps this readable
					local msg_by_severity = {
						[vim.diagnostic.severity.ERROR] = diagnostic.message,
						[vim.diagnostic.severity.WARN] = diagnostic.message,
						[vim.diagnostic.severity.INFO] = diagnostic.message,
						[vim.diagnostic.severity.HINT] = diagnostic.message,
					}
					return msg_by_severity[diagnostic.severity]
				end,
			},
		})

		---------------------------------------------------------------------------
		-- Capabilities (blink.cmp) – applied via vim.lsp.config('*', …)
		---------------------------------------------------------------------------
		local capabilities = require("blink.cmp").get_lsp_capabilities()

		-- Default config that applies to *all* LSP configs (including those from
		-- nvim-lspconfig and any local lsp/*.lua configs).
		-- See :help lsp-config
		vim.lsp.config("*", {
			capabilities = capabilities,
		})

		---------------------------------------------------------------------------
		-- Servers + settings (per-server vim.lsp.config)
		---------------------------------------------------------------------------
		-- Keys here are nvim-lspconfig server names.
		local servers = {
			gopls = {},
			marksman = {},
			html = {
				filetypes = { "html", "twig", "hbs" },
			},
			ts_ls = {},
			lua_ls = {
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
						},
						-- diagnostics = { disable = { "missing-fields" } },
					},
				},
			},
		}

		-- Per-server config merges with the base config provided by nvim-lspconfig.
		-- (See nvim-lspconfig README for how this merging works.)
		for name, cfg in pairs(servers) do
			-- only call when there is something to add/override
			if cfg and next(cfg) ~= nil then
				vim.lsp.config(name, cfg)
			end
		end

		---------------------------------------------------------------------------
		-- Mason tool installer: make sure servers (+ stylua) are installed
		---------------------------------------------------------------------------
		local ensure_installed = vim.tbl_keys(servers)
		table.insert(ensure_installed, "stylua")

		require("mason-tool-installer").setup({
			ensure_installed = ensure_installed,
		})
		-- mason-lspconfig (with opts = {}) will automatically:
		--   * translate Mason packages <-> lspconfig names
		--   * call vim.lsp.enable() for installed servers

		---------------------------------------------------------------------------
		-- Custom Go-aware `gd` for _templ.go -> .templ
		---------------------------------------------------------------------------
		local function debug_log(_msg)
			-- Uncomment if you want to debug:
			-- vim.api.nvim_out_write("[GoToDef Debug]: " .. _msg .. "\n")
			-- vim.notify("[GoToDef Debug]: " .. _msg, vim.log.levels.INFO)
		end

		local function go_to_definition()
			if vim.bo.filetype ~= "go" then
				debug_log("Not a Go file. Using default go-to-definition.")
				vim.lsp.buf.definition()
				return
			end

			debug_log("Go file detected. Requesting definition...")

			vim.lsp.buf_request(
				0,
				"textDocument/definition",
				vim.lsp.util.make_position_params(),
				function(err, result, ctx, _)
					if err then
						debug_log("LSP Error: " .. err.message)
						return
					end

					if not result or vim.tbl_isempty(result) then
						debug_log("LSP returned no definition results.")
						return
					end

					local target = result[1]
					if not target or not target.uri then
						debug_log("Invalid target or missing URI in LSP response.")
						return
					end

					local target_file = vim.uri_to_fname(target.uri)
					debug_log("LSP resolved definition to: " .. target_file)

					local prefix = string.match(target_file, "(.-)_templ%.go$")
					if prefix then
						debug_log("Matched _templ.go file. Switching to .templ equivalent.")
						local function_name = vim.fn.expand("<cword>")
						local templ_file = prefix .. ".templ"

						debug_log("Opening: " .. templ_file)
						vim.cmd.edit(templ_file)

						debug_log("Searching for function: " .. function_name)
						vim.cmd("silent! /" .. function_name)
					else
						debug_log("No _templ.go match. Using default LSP go-to-definition.")
						vim.lsp.buf.definition()
					end
				end
			)
		end

		-- Simple, buffer-agnostic mapping for gd
		vim.keymap.set("n", "gd", go_to_definition, {
			noremap = true,
			silent = true,
			desc = "LSP: Go to definition (templ-aware for Go)",
		})
	end,
}
