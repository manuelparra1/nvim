local terminal_background = "#1e1e2e"
local buffer_color = "#313244"
local buffer_text = "#a6adc8"
local unfocused_color = "#101010"
local unfocused_text = "#313244"
return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	version = "*",
	config = function()
		require("bufferline").setup({
			options = {
				mode = "buffers",
				tab_size = 20,
				separator_style = "slant",
			},
			highlights = {
				fill = {
					-- Tab Background = Terminal Background
					bg = terminal_background,
				},
				background = {
					-- Color of Unfocused "Tab" background
					bg = unfocused_color,
					fg = unfocused_text,
				},
				close_button = {
					-- Color of Unfocused "Tab" (x) Close Button
					bg = unfocused_color,
					fg = unfocused_text,
				},
				modified = {
					bg = unfocused_color,
				},
				separator = {
					-- Unfocused Tab
					-- The Slant contrasting background; it's the "bg"
					-- Matches Terminal Background for selected "Tab"
					fg = terminal_background,
					-- Adds Color to "Slant Shape" of "Tab"; it's the "fg"
					bg = unfocused_color,
				},
				-- buffer_visible = {
				-- 	-- Color of Selected "Tab"
				-- 	-- I'm matching it to the neovim buffer background color
				-- 	bg = "#101010",
				-- 	bold = true,
				-- 	italic = true,
				-- },
				buffer_selected = {
					-- Color of Selected "Tab"
					-- I'm matching it to the neovim buffer background color
					bg = buffer_color,
					fg = buffer_text,
					bold = true,
					italic = true,
				},
				separator_selected = {
					-- The Slant contrasting background; it's the "bg"
					-- Matches Terminal Background for selected "Tab" slant background
					fg = terminal_background,
					-- Adds Color to "Slant Shape" of "Tab"; it's the "fg"
					bg = buffer_color,
				},
				close_button_selected = {
					-- Color of Selected "Tab" background for "Close" button
					bg = buffer_color,
				},
				modified_selected = {
					-- Color of Selected "Tab" background for "Modified" indicator
					bg = buffer_color,
				},
				-- separator_visible = {
				-- 	-- The Slant contrasting background; it's the "bg"
				-- 	-- Matches Terminal Background for selected "Tab"
				-- 	fg = "#323232",
				-- 	-- Adds Color to "Slant Shape" of "Tab"; it's the "fg"
				-- 	bg = "#101010",
				-- },
				-- separator_selected = {
				-- 	fg = "#323232",
				-- },
				-- separator_visible = {
				-- 	fg = "#323232",
				-- },
				-- separator = {
				-- 	fg = "#323232",
				-- },
			},
		})
	end,
}
