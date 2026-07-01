return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	opts = {
		-- Define your custom labels here
		spec = {
			{ "<leader>m", group = "Markdown AI Custom Prompts", mode = "v" },
			-- Paragraphs
			{ "<leader>mg", group = "Generators", mode = "v" },
			-- Bullet Points
			{ "<leader>me", group = "Explain It Peter!", mode = "v" },
			{ "<Leader>my", group = "YouTube Prompts", mode = "v" },
			{ "<leader>mc", group = "Markdown AI Response Cleaners", mode = "v" },
			{ "<leader>ms", group = "Markdown AI Scrape Cleaners", mode = "v" },
			{ "<leader>n", group = "AI Notes", mode = "v" },
			{ "<leader>nm", group = "M AI's", mode = "v" },
			{ "<leader>t", group = "Tiny AI's", mode = "v" },
			{ "<leader>me", group = "AI Notes" },
			{ "<leader>ms", group = "AI Strippers" }, -- Names the 'ms' sub-menu
			{ "<leader>g", group = "Live Grep Files", icon = { icon = "󰡦", color = "green" } },
			{ "<leader>f", group = "Fuzzy Find", icon = { icon = "", color = "green" } },
		},
	},
}
