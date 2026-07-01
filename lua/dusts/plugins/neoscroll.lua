return {
	"karb94/neoscroll.nvim",
	config = function()
		local neoscroll = require("neoscroll")

		neoscroll.setup({
			-- Disable the default mappings so they don't interfere
			mappings = {},
			hide_cursor = true,
		})

		-- Define your custom mappings
		local keymap = {
			["<C-u>"] = function()
				neoscroll.scroll(-10, { move_cursor = true, duration = 250 })
			end,
			["<C-d>"] = function()
				neoscroll.scroll(10, { move_cursor = true, duration = 250 })
			end,

			-- You can still use vim.wo.scroll if you want dynamic behavior
			["<C-b>"] = function()
				neoscroll.scroll(-vim.wo.scroll, { move_cursor = true, duration = 250 })
			end,
			["<C-f>"] = function()
				neoscroll.scroll(vim.wo.scroll, { move_cursor = true, duration = 250 })
			end,

			-- Percentage scrolling (0.10 = 10%)
			["<C-y>"] = function()
				neoscroll.scroll(-0.10, { move_cursor = false, duration = 100 })
			end,
			["<C-e>"] = function()
				neoscroll.scroll(0.10, { move_cursor = false, duration = 100 })
			end,
		}

		local modes = { "n", "v", "x" }
		for key, func in pairs(keymap) do
			vim.keymap.set(modes, key, func)
		end
	end,
}
