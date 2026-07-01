return {
	{
		"folke/zen-mode.nvim",
		opts = {
			window = {
				backdrop = 0.95,
				width = 80,
				height = 1,
			},
			plugins = {
				twilight = { enabled = true },
				kitty = {
					enabled = true,
					font = "+8", -- increments from your base 18 → 24
				},
			},
		},
	},
	{
		"folke/twilight.nvim",
		opts = {
			dimming = {
				alpha = 0.25, -- The opacity of the dimmed text
				color = { "Normal", "#ffffff" },
			},
			context = 2, -- How many lines to keep visible outside the current node
			treesitter = true, -- Crucial for Markdown parsing
			expand = {
				"paragraph", -- Tells Twilight to focus on the whole paragraph node
				"markdown",
			},
		},
	},
}
