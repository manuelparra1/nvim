return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		keywords = {
			TODO = { icon = " ", color = "info" },
			FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG" } },
			HACK = { color = "warning" },
		},
		highlight = { comments_only = true }, -- uses Treesitter so it won't match in strings
		search = { command = "rg" }, -- ripgrep is used for fast project search
	},
}
