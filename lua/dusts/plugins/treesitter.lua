return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",

		config = function()
			local ts = require("nvim-treesitter")

			ts.setup({
				install_dir = vim.fn.stdpath("data") .. "/site",
			})

			ts.install({
				"bash",
				"lua",
				"vim",
				"javascript",
				"typescript",
				"markdown",
				"markdown_inline",
				"regex",
				"query",
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"bash",
					"lua",
					"vim",
					"javascript",
					"typescript",
					"markdown",
				},
				callback = function()
					vim.treesitter.start()
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
}
