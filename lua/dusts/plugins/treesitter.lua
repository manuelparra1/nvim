return {
	-- 1. Core Treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false, -- The rewrite strictly forbids lazy-loading
		build = ":TSUpdate",
		config = function()
			-- Your custom list of parsers
			local parsers = {
				"json",
				"javascript",
				"typescript",
				"tsx",
				"yaml",
				"html",
				"css",
				"prisma",
				"markdown",
				"markdown_inline",
				"svelte",
				"graphql",
				"bash",
				"lua",
				"vim",
				"dockerfile",
				"gitignore",
				"query",
			}

			-- Install missing parsers automatically
			require("nvim-treesitter").install(parsers)

			-- Enable native Neovim features for all filetypes
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function()
					-- Enable syntax highlighting
					pcall(vim.treesitter.start)

					-- Enable experimental indentation
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

					-- Enable code folding based on treesitter
					-- vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					-- vim.wo.foldmethod = "expr"
				end,
			})
		end,
	},

	-- 2. Autotag Plugin
	{
		"windwp/nvim-ts-autotag",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			-- Modern autotag setup (independent of treesitter config)
			require("nvim-ts-autotag").setup({
				enable = true,
			})
		end,
	},

	-- 3. Textobjects Plugin
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
}
