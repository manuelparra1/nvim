return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		require("mason").setup()

		require("mason-lspconfig").setup({
			ensure_installed = { "lua_ls", "marksman", "pyright", "html", "cssls" },
			automatic_installation = true,
		})

		require("mason-tool-installer").setup({
			ensure_installed = {
				"prettier", -- markdown/html/css formatting
				"stylua", -- lua formatting
				"black", -- python formatting
				"isort", -- python sort imports
				"markdownlint", -- markdown linting
				"selene", -- lua linting
				"shellcheck", -- shell linting
				"flake8", -- python linting
				"cpplint", -- cpp linting
				"djlint", -- html linting
			},
		})
	end,
}
