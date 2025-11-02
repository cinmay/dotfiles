return {
    "neovim/nvim-lspconfig",
    config = function()
        local function debug_log(msg)
            -- vim.notify("[GoToDef Debug]: " .. msg, vim.log.levels.INFO)
            -- vim.api.nvim_out_write("[GoToDef Debug]: " .. msg .. "\n")
        end

        local go_to_definition = function()
            if vim.bo.filetype == "go" then
                debug_log("Go file detected. Requesting definition...")

                vim.lsp.buf_request(0, "textDocument/definition", vim.lsp.util.make_position_params(),
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
                            vim.cmd("edit " .. templ_file)

                            debug_log("Searching for function: " .. function_name)
                            vim.api.nvim_command("silent! /" .. function_name)
                        else
                            debug_log("No _templ.go match. Using default LSP go-to-definition.")
                            vim.lsp.buf.definition()
                        end
                    end)
            else
                debug_log("Not a Go file. Using default go-to-definition.")
                vim.lsp.buf.definition()
            end
        end

        local function go_goto_def()
            debug_log("Keymap triggered for go-to-definition.")
            if vim.bo.filetype == "go" then
                return go_to_definition()
            else
                return vim.lsp.buf.definition()
            end
        end

        -- Apply keymap for 'gd' globally without LazyVim
        vim.api.nvim_set_keymap("n", "gd", "<cmd>lua _G.go_goto_def()<CR>",
            { noremap = true, silent = true })

        -- Make `go_goto_def` available globally for keymap
        _G.go_goto_def = go_goto_def
    end,
}
