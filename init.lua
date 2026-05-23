-- ~/.config/nvim/init.lua
-- whyCARE v3 — Sovereign Neovim Configuration
-- Stack: lazy.nvim | Theme: Catppuccin Mocha | AI: Ollama local
-- Fixes: vim.uv API, vim.bo accessor, async completion

-- ==============================================================================
-- BOOTSTRAP LAZY.NVIM
-- ==============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- ==============================================================================
-- GLOBAL OPTIONS (before plugin load)
-- ==============================================================================
vim.g.mapleader        = " "
vim.g.maplocalleader   = " "
vim.g.have_nerd_font   = true

-- FIXED: Use stable vim.bo API throughout (not deprecated nvim_buf_get_option)
local opt = vim.opt
opt.number            = true
opt.relativenumber    = true
opt.signcolumn        = "yes"
opt.splitbelow        = true
opt.splitright        = true
opt.tabstop           = 4
opt.shiftwidth        = 4
opt.softtabstop       = 4
opt.expandtab         = true
opt.smartindent       = true
opt.wrap              = false
opt.linebreak         = true
opt.termguicolors     = true
opt.cursorline        = true
opt.scrolloff         = 8
opt.sidescrolloff     = 8
opt.hlsearch          = true
opt.incsearch         = true
opt.ignorecase        = true
opt.smartcase         = true
opt.undofile          = true
opt.undodir           = vim.fn.expand("~/.local/share/nvim/undo")
opt.swapfile          = false
opt.backup            = false
opt.updatetime        = 250
opt.timeoutlen        = 300
opt.completeopt       = "menuone,noselect,preview"
opt.pumheight         = 12
opt.conceallevel      = 1
opt.foldmethod        = "expr"
opt.foldexpr          = "nvim_treesitter#foldexpr()"
opt.foldlevel         = 99
opt.foldlevelstart    = 99
opt.list              = true
opt.listchars         = { tab = "→ ", trail = "·", nbsp = "⎵" }
opt.fillchars         = { eob = " ", fold = " ", foldopen = "", foldclose = "" }
opt.clipboard         = "unnamedplus"   -- Wayland: use wl-clipboard

-- uv-managed Python path (FIXED: check before assigning)
local uv_python = vim.fn.expand("~/.local/share/uv/tools/neovim/bin/python3")
if vim.fn.filereadable(uv_python) == 1 then
    vim.g.python3_host_prog = uv_python
else
    -- Fallback to system python3
    local sys_python = vim.fn.exepath("python3")
    if sys_python ~= "" then vim.g.python3_host_prog = sys_python end
end

-- ==============================================================================
-- PLUGINS
-- ==============================================================================
require("lazy").setup({
    -- ── Colorscheme: Catppuccin Mocha ─────────────────────────────────────────
    {
        "catppuccin/nvim",
        name     = "catppuccin",
        priority = 1000,
        opts = {
            flavour         = "mocha",
            transparent_background = false,
            show_end_of_buffer = true,
            term_colors     = true,
            dim_inactive = {
                enabled    = true,
                shade      = "dark",
                percentage = 0.15,
            },
            integrations = {
                cmp              = true,
                gitsigns         = true,
                nvimtree         = true,
                telescope        = { enabled = true },
                treesitter       = true,
                mason            = true,
                which_key        = true,
                indent_blankline = { enabled = true },
                lsp_trouble      = true,
                mini             = { enabled = true },
                noice            = true,
                notify           = false,
                dashboard        = true,
            },
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- ── File tree ─────────────────────────────────────────────────────────────
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            sort_by       = "case_sensitive",
            renderer = {
                group_empty = true,
                icons = { show = { file = true, folder = true, git = true } },
            },
            filters = { dotfiles = false },
            git     = { enable = true },
        },
        keys = {
            { "<leader>e",  "<cmd>NvimTreeToggle<cr>",   desc = "File tree" },
            { "<leader>fe", "<cmd>NvimTreeFindFile<cr>", desc = "Find in tree" },
        },
    },

    -- ── Statusline ───────────────────────────────────────────────────────────
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                theme            = "catppuccin",
                section_separators   = { left = "", right = "" },
                component_separators = { left = "", right = "" },
                globalstatus     = true,
            },
            sections = {
                lualine_a = { { "mode", separator = { left = "" }, padding = { left = 0, right = 1 } } },
                lualine_b = { "branch", "diff", "diagnostics" },
                lualine_c = { { "filename", path = 1 } },
                lualine_x = {
                    { function() return "  " .. (vim.bo.filetype ~= "" and vim.bo.filetype or "plain") end },
                    "encoding",
                    "fileformat",
                },
                lualine_y = { "progress" },
                lualine_z = { { "location", separator = { right = "" }, padding = { left = 1, right = 0 } } },
            },
        },
    },

    -- ── Bufferline ───────────────────────────────────────────────────────────
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = "nvim-tree/nvim-web-devicons",
        opts = {
            options = {
                mode              = "buffers",
                theme             = "catppuccin",
                separator_style   = "slant",
                diagnostics       = "nvim_lsp",
                offsets           = { { filetype = "NvimTree", text = " File Explorer", padding = 1 } },
            },
        },
    },

    -- ── Telescope (fuzzy finder) ─────────────────────────────────────────────
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            "nvim-telescope/telescope-ui-select.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            local telescope = require("telescope")
            local actions   = require("telescope.actions")
            telescope.setup({
                defaults = {
                    prompt_prefix    = " ❯ ",
                    selection_caret  = " ▸ ",
                    entry_prefix     = "   ",
                    layout_strategy  = "horizontal",
                    layout_config    = { horizontal = { preview_width = 0.55 } },
                    mappings = {
                        i = {
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
                            ["<esc>"] = actions.close,
                        },
                    },
                },
                extensions = {
                    fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true },
                    ["ui-select"] = { require("telescope.themes").get_dropdown() },
                },
            })
            telescope.load_extension("fzf")
            telescope.load_extension("ui-select")
        end,
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<cr>",                   desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<cr>",                    desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<cr>",                      desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<cr>",                    desc = "Help" },
            { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                     desc = "Recent files" },
            { "<leader>fc", "<cmd>Telescope grep_string<cr>",                  desc = "Find word" },
            { "<leader>fd", "<cmd>Telescope diagnostics<cr>",                  desc = "Diagnostics" },
            { "<leader>fk", "<cmd>Telescope keymaps<cr>",                      desc = "Keymaps" },
            { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>",         desc = "LSP symbols" },
            { "<leader>fw", "<cmd>Telescope lsp_workspace_symbols<cr>",        desc = "Workspace symbols" },
            { "<leader>gc", "<cmd>Telescope git_commits<cr>",                  desc = "Git commits" },
            { "<leader>gs", "<cmd>Telescope git_status<cr>",                   desc = "Git status" },
        },
    },

    -- ── Treesitter ───────────────────────────────────────────────────────────
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "bash", "c", "cpp", "css", "dockerfile", "go", "html",
                    "json", "jsonc", "kdl", "lua", "luadoc", "markdown",
                    "markdown_inline", "nix", "nu", "python", "query",
                    "regex", "rust", "sql", "toml", "typescript", "vim",
                    "vimdoc", "yaml",
                },
                auto_install    = true,
                highlight       = { enable = true, additional_vim_regex_highlighting = false },
                indent          = { enable = true },
                textobjects = {
                    select = {
                        enable    = true,
                        lookahead = true,
                        keymaps = {
                            ["af"] = "@function.outer",
                            ["if"] = "@function.inner",
                            ["ac"] = "@class.outer",
                            ["ic"] = "@class.inner",
                            ["aa"] = "@parameter.outer",
                            ["ia"] = "@parameter.inner",
                        },
                    },
                    move = {
                        enable              = true,
                        set_jumps           = true,
                        goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
                        goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
                    },
                },
            })
        end,
    },

    -- ── LSP stack (Mason + nvim-lspconfig) ───────────────────────────────────
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
            { "j-hui/fidget.nvim", opts = {} },
            { "folke/neodev.nvim", opts = {} },
        },
        config = function()
            require("mason").setup({ ui = { border = "rounded" } })
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls", "pyright", "bashls", "yamlls",
                    "jsonls", "nixd", "rust_analyzer",
                },
            })
            require("mason-tool-installer").setup({
                ensure_installed = {
                    "black", "isort", "stylua", "shfmt",
                    "shellcheck", "prettier", "pylint",
                },
            })

            -- LSP on-attach keymaps
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("whycare-lsp-attach", { clear = true }),
                callback = function(event)
                    local map = function(keys, func, desc)
                        vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
                    end
                    map("gd",  require("telescope.builtin").lsp_definitions,      "Go to definition")
                    map("gr",  require("telescope.builtin").lsp_references,        "References")
                    map("gI",  require("telescope.builtin").lsp_implementations,   "Implementations")
                    map("K",   vim.lsp.buf.hover,                                  "Hover docs")
                    map("<leader>rn", vim.lsp.buf.rename,                          "Rename")
                    map("<leader>ca", vim.lsp.buf.code_action,                     "Code action")
                    map("<leader>D",  require("telescope.builtin").lsp_type_definitions, "Type definition")
                    map("<leader>ds", require("telescope.builtin").lsp_document_symbols,  "Document symbols")
                    map("gD",  vim.lsp.buf.declaration,                            "Go to declaration")
                    map("[d",  vim.diagnostic.goto_prev,                           "Prev diagnostic")
                    map("]d",  vim.diagnostic.goto_next,                           "Next diagnostic")
                    map("<leader>q",  vim.diagnostic.setloclist,                   "Diagnostic list")
                end,
            })

            -- Configure individual LSPs
            local lspconfig = require("lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            lspconfig.lua_ls.setup({
                capabilities = capabilities,
                settings = { Lua = { diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false } } },
            })
            lspconfig.pyright.setup({ capabilities = capabilities })
            lspconfig.bashls.setup({ capabilities = capabilities })
            lspconfig.nixd.setup({ capabilities = capabilities })
            lspconfig.rust_analyzer.setup({ capabilities = capabilities })
        end,
    },

    -- ── Completion (nvim-cmp) ─────────────────────────────────────────────────
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "rafamadriz/friendly-snippets",
        },
        config = function()
            local cmp    = require("cmp")
            local luasnip= require("luasnip")
            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
                window  = {
                    completion    = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-n>"]   = cmp.mapping.select_next_item(),
                    ["<C-p>"]   = cmp.mapping.select_prev_item(),
                    ["<C-b>"]   = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"]   = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"]= cmp.mapping.complete(),
                    ["<C-e>"]   = cmp.mapping.abort(),
                    ["<CR>"]    = cmp.mapping.confirm({ select = true }),
                    ["<Tab>"]   = cmp.mapping(function(fallback)
                        if cmp.visible() then cmp.select_next_item()
                        elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
                        else fallback() end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then cmp.select_prev_item()
                        elseif luasnip.locally_jumpable(-1) then luasnip.jump(-1)
                        else fallback() end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end,
    },

    -- ── Git ───────────────────────────────────────────────────────────────────
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            signs = {
                add          = { text = "│" },
                change       = { text = "│" },
                delete       = { text = "󰍵" },
                topdelete    = { text = "‾" },
                changedelete = { text = "~" },
                untracked    = { text = "│" },
            },
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end
                map("n", "]h",  gs.next_hunk,         "Next hunk")
                map("n", "[h",  gs.prev_hunk,         "Prev hunk")
                map("n", "<leader>hs", gs.stage_hunk,  "Stage hunk")
                map("n", "<leader>hr", gs.reset_hunk,  "Reset hunk")
                map("n", "<leader>hS", gs.stage_buffer,"Stage buffer")
                map("n", "<leader>hp", gs.preview_hunk,"Preview hunk")
                map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
                map("n", "<leader>hd", gs.diffthis,    "Diff this")
            end,
        },
    },
    { "tpope/vim-fugitive",  cmd = "Git" },
    {
        "kdheepak/lazygit.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = { { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" } },
    },

    -- ── Which-key (hotkey discovery) ─────────────────────────────────────────
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            window = { border = "rounded" },
            layout = { align = "center" },
        },
        config = function(_, opts)
            local wk = require("which-key")
            wk.setup(opts)
            wk.register({
                ["<leader>f"]  = { name = "Find/Files" },
                ["<leader>g"]  = { name = "Git" },
                ["<leader>h"]  = { name = "Hunks" },
                ["<leader>l"]  = { name = "LLM/AI" },
                ["<leader>t"]  = { name = "Terminal" },
                ["<leader>x"]  = { name = "Trouble/Errors" },
            })
        end,
    },

    -- ── Formatting ───────────────────────────────────────────────────────────
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        opts = {
            formatters_by_ft = {
                lua     = { "stylua" },
                python  = { "isort", "black" },
                bash    = { "shfmt" },
                sh      = { "shfmt" },
                nix     = { "nixpkgs-fmt" },
                markdown= { "prettier" },
                json    = { "prettier" },
                yaml    = { "prettier" },
            },
            format_on_save = { lsp_fallback = true, timeout_ms = 2000 },
        },
    },

    -- ── Diagnostics/Trouble ───────────────────────────────────────────────────
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {},
        keys = {
            { "<leader>xx", "<cmd>TroubleToggle<cr>",                       desc = "Trouble toggle" },
            { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace diagnostics" },
            { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>",  desc = "Document diagnostics" },
        },
    },

    -- ── Terminal (toggleterm) ─────────────────────────────────────────────────
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        opts = {
            size        = 20,
            open_mapping= [[<c-\>]],
            direction   = "float",
            float_opts  = { border = "curved" },
            shell       = "nu",                 -- Default to Nushell
        },
        keys = {
            { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal terminal" },
            { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>",   desc = "Vertical terminal" },
            { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>",      desc = "Float terminal" },
            { "<leader>tz", "<cmd>ToggleTerm direction=tab<cr>",        desc = "Tab terminal" },
            { "<leader>tg", function()
                require("toggleterm.terminal").Terminal:new({
                    cmd = "lazygit", direction = "float",
                    float_opts = { border = "curved" },
                }):toggle()
            end, desc = "LazyGit terminal" },
            { "<leader>tk", function()
                require("toggleterm.terminal").Terminal:new({
                    cmd = "ollama run llama3.1", direction = "float",
                    float_opts = { border = "curved" },
                }):toggle()
            end, desc = "LLM terminal" },
        },
    },

    -- ── Markdown rendering ────────────────────────────────────────────────────
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        ft = { "markdown" },
        opts = {
            enabled = true,
            render_modes = { "n", "c" },
            heading = { enabled = true, width = "full" },
            code    = { enabled = true, width = "block", min_width = 60 },
        },
    },

    -- ── misc QoL plugins ──────────────────────────────────────────────────────
    { "windwp/nvim-autopairs",    event = "InsertEnter", opts = { check_ts = true } },
    { "numToStr/Comment.nvim",    opts = {} },
    { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
    { "folke/todo-comments.nvim", dependencies = "nvim-lua/plenary.nvim", opts = {} },
    { "NvChad/nvim-colorizer.lua", opts = { user_default_options = { mode = "background" } } },
    { "RRethy/vim-illuminate", event = "BufReadPost" },
    {
        "folke/noice.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        opts = {
            lsp = { override = { ["vim.lsp.util.convert_input_to_markdown_lines"] = true, ["vim.lsp.util.stylize_markdown"] = true } },
            presets = { bottom_search = true, command_palette = true, long_message_to_split = true },
        },
    },
    { "nvim-pack/nvim-spectre",  keys = { { "<leader>S", function() require("spectre").toggle() end, desc = "Spectre (search/replace)" } } },
}, {
    ui = {
        border = "rounded",
        icons  = {
            cmd    = " ",
            config = "",
            event  = "",
            ft     = " ",
            init   = " ",
            import = " ",
            keys   = " ",
            lazy   = "󰒲 ",
            loaded = "●",
            not_loaded = "○",
            plugin = " ",
            runtime = " ",
            require = "󰢱 ",
            source = " ",
            start  = " ",
            task   = "✔ ",
            list   = { "●", "➜", "★", "‒" },
        },
    },
})

-- ==============================================================================
-- AUTOCMDS
-- ==============================================================================
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local sovereign = augroup("SovereignSystems", { clear = true })

-- Autosave markdown (for Logseq journals)
autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group   = sovereign,
    pattern = "*.md",
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        -- FIXED: use vim.bo[buf] not deprecated nvim_buf_get_option
        if vim.bo[buf].modified then
            vim.cmd("silent! write")
        end
    end,
})

-- Markdown-specific settings
autocmd("FileType", {
    group   = sovereign,
    pattern = "markdown",
    callback = function()
        vim.opt_local.wrap       = true
        vim.opt_local.linebreak  = true
        vim.opt_local.foldlevel  = 99

        -- Smart list continuation on Enter
        vim.keymap.set("i", "<Enter>", function()
            local line = vim.api.nvim_get_current_line()
            if line:match("^%s*%- %[[ x]%] ") then
                return "<CR>- [ ] "
            elseif line:match("^%s*%- ") then
                return "<CR>- "
            elseif line:match("^%s*%d+%. ") then
                local num = tonumber(line:match("^%s*(%d+)%.")) or 0
                return "<CR>" .. (num + 1) .. ". "
            else
                return "<CR>"
            end
        end, { buffer = true, expr = true })
    end,
})

-- Highlight on yank
autocmd("TextYankPost", {
    group    = sovereign,
    callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
    end,
})

-- Restore cursor position
autocmd("BufReadPost", {
    group = sovereign,
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(ev.buf)
        if mark[1] > 0 and mark[1] <= line_count then
            vim.api.nvim_feedkeys('g`"', "n", false)
        end
    end,
})

-- ==============================================================================
-- LOCAL LLM ASYNC COMPLETION ENGINE
-- FIXED: Uses vim.uv (replaces deprecated vim.loop)
-- ==============================================================================
local function invoke_local_llm(model)
    model = model or "llama3.1"
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line_text = vim.api.nvim_get_current_line()

    -- Include surrounding context for better completions
    local buf_lines = vim.api.nvim_buf_get_lines(0, math.max(0, row - 5), row, false)
    local context = table.concat(buf_lines, "\n")

    local payload = vim.fn.json_encode({
        model  = model,
        prompt = "Complete this code/text concisely. Only output the completion, no explanation:\n\n" .. context,
        stream = false,
    })

    local response_buffer = ""
    -- FIXED: vim.uv replaces deprecated vim.loop (Neovim 0.10+)
    local stdout = vim.uv.new_pipe(false)
    local process_handle

    process_handle, _ = vim.uv.spawn("curl", {
        args  = { "-sS", "-X", "POST", "http://127.0.0.1:11434/api/generate",
                  "-H", "Content-Type: application/json", "-d", payload },
        stdio = { nil, stdout, nil },
    }, function(_code, _signal)
        stdout:close()
        if process_handle and not process_handle:is_closing() then
            process_handle:close()
        end

        vim.schedule(function()
            local ok, parsed = pcall(vim.fn.json_decode, response_buffer)
            if ok and parsed and parsed.response then
                local lines = vim.split(parsed.response, "\n", { plain = true })
                vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
                vim.notify("LLM completion inserted (" .. model .. ")", vim.log.levels.INFO)
            else
                vim.notify("LLM: no completion received", vim.log.levels.WARN)
            end
        end)
    end)

    vim.uv.read_start(stdout, function(err, data)
        if err then return end
        if data then response_buffer = response_buffer .. data end
    end)
end

-- LLM keymaps
vim.keymap.set("n", "<leader>ll", function() invoke_local_llm("llama3.1") end,      { desc = "LLM: llama3.1 completion" })
vim.keymap.set("n", "<leader>lc", function() invoke_local_llm("codellama:13b") end, { desc = "LLM: codellama completion" })
vim.keymap.set("n", "<leader>lf", function() invoke_local_llm("mistral:7b-instruct") end, { desc = "LLM: fast completion" })

-- LLM explain selection (visual mode)
vim.keymap.set("v", "<leader>le", function()
    local start_pos = vim.api.nvim_buf_get_mark(0, "<")
    local end_pos   = vim.api.nvim_buf_get_mark(0, ">")
    local lines     = vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, end_pos[1], false)
    local selected  = table.concat(lines, "\n")

    local payload = vim.fn.json_encode({
        model  = "llama3.1",
        prompt = "Explain this code/text concisely from a security perspective:\n\n" .. selected,
        stream = false,
    })

    local result = ""
    local stdout = vim.uv.new_pipe(false)
    local handle
    handle, _ = vim.uv.spawn("curl", {
        args  = { "-sS", "-X", "POST", "http://127.0.0.1:11434/api/generate",
                  "-H", "Content-Type: application/json", "-d", payload },
        stdio = { nil, stdout, nil },
    }, function()
        stdout:close()
        handle:close()
        vim.schedule(function()
            local ok, parsed = pcall(vim.fn.json_decode, result)
            if ok and parsed and parsed.response then
                -- Open in floating window
                local buf = vim.api.nvim_create_buf(false, true)
                local explanation_lines = vim.split(parsed.response, "\n")
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, explanation_lines)
                vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
                local width  = math.min(80, vim.o.columns - 4)
                local height = math.min(#explanation_lines, 20)
                vim.api.nvim_open_win(buf, true, {
                    relative = "cursor",
                    row = 1, col = 0,
                    width = width, height = height,
                    style = "minimal", border = "rounded",
                    title = " LLM Explanation ", title_pos = "center",
                })
            end
        end)
    end)
    vim.uv.read_start(stdout, function(err, data)
        if err then return end
        if data then result = result .. data end
    end)
end, { desc = "LLM: explain selection" })

-- ==============================================================================
-- GENERAL KEYMAPS
-- ==============================================================================
local map = vim.keymap.set

-- Navigation
map("n", "<C-h>", "<C-w>h",    { desc = "Split left" })
map("n", "<C-j>", "<C-w>j",    { desc = "Split down" })
map("n", "<C-k>", "<C-w>k",    { desc = "Split up" })
map("n", "<C-l>", "<C-w>l",    { desc = "Split right" })
map("n", "<leader>sv", "<C-w>v", { desc = "Split vertical" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split horizontal" })
map("n", "<leader>se", "<C-w>=", { desc = "Equal splits" })
map("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close split" })

-- Buffer navigation
map("n", "<S-h>",  "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>",  "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Quick operations
map("n", "<leader>w", "<cmd>w<cr>",  { desc = "Save" })
map("n", "<leader>W", "<cmd>wa<cr>", { desc = "Save all" })
map("n", "<leader>q", "<cmd>q<cr>",  { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa!<cr>",{ desc = "Force quit all" })
map("n", "<Esc>",  "<cmd>nohlsearch<cr>", { desc = "Clear search" })

-- Better motions in wrapped lines
map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })

-- Indent and stay in visual mode
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- Diagnostic navigation
map("n", "[d", vim.diagnostic.goto_prev,              { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next,              { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float,      { desc = "Diagnostic float" })

-- Quick snapper snapshot from Neovim
map("n", "<leader>as", function()
    vim.cmd("terminal sudo snapper -c root create --description 'NVIM-PRE-EDIT'")
end, { desc = "BTRFS snapshot" })
