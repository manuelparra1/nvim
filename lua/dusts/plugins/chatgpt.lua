return {
	"jackMort/ChatGPT.nvim",
	event = "VeryLazy",
	config = function()
		require("chatgpt").setup({
			popup_window = {
				border = {
					highlight = "FloatBorder",
					style = "rounded",
					text = {
						top = " Infinite Power!!! ",
					},
				},
			},
			openai_edit_params = {
				model = "gpt-4o-mini",
				frequency_penalty = 0,
				presence_penalty = 0,
				temperature = 0,
				top_p = 1,
				n = 1,
			},
		})

		-- Keymaps
		-- ChatGPT
		vim.api.nvim_set_keymap("n", "<leader>gp", "<cmd>ChatGPT<CR>", { noremap = true, silent = true })
		-- Edit With Instructions function
		vim.api.nvim_set_keymap(
			"v",
			"<leader>gi",
			"<cmd>ChatGPTEditWithInstruction<CR>",
			{ noremap = true, silent = true }
		)
	end,
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"folke/trouble.nvim",
		"nvim-telescope/telescope.nvim",
	},
}
