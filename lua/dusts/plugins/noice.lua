return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
	config = function()
		require("noice").setup({
			-- The Window For Searching
			cmdline = {
				format = {
					-- Update the icon for forward search (/)
					search_down = {
						kind = "search",
						pattern = "^/",
						icon = " ",
						lang = "regex",
					},
					-- Update the icon for backward search (?)
					search_up = {
						kind = "search",
						pattern = "^%?",
						icon = " ",
						lang = "regex",
					},
				},
			},
			-- 1. THE TRAFFIC COPS (Routes)
			-- These decide which View a message goes to based on its 'kind'
			routes = {
				-- Macro Mode Fix
				{
					filter = { event = "msg_showmode" },
					-- view = "cmdline",
					view = "mini_info",
				},
				-- Search Count --> Virtual Text
				{
					filter = { event = "msg_show", kind = "search_count" },
					view = "virtualtext",
					opts = {
						format = {
							-- 1. The Magnifying Glass Icon
							{ " ", hl_group = "NoiceCmdlineIconSearch" },
							-- 2. The Search Count Text (e.g. "[2/5]")
							{ "{message}" },
						},
					},
				},
				-- Errors -> Red View
				{ filter = { event = "notify", kind = "error" }, view = "mini_error" },
				{ filter = { event = "msg_show", kind = "echo" }, view = "mini_error" }, -- Catch command line errors

				-- Warnings -> Yellow View
				{ filter = { event = "notify", kind = "warn" }, view = "mini_warn" },

				-- Info -> Blue View (Default for most notifications)
				{ filter = { event = "notify", kind = "info" }, view = "mini_info" },

				-- Hints -> Teal/Green View (Optional, but good for completeness)
				{ filter = { event = "notify", kind = "hint" }, view = "mini_hint" },

				-- Catch-all for other messages (like print statements) -> Info View
				{ filter = { event = "msg_show" }, view = "mini_info" },
			},

			-- 2. THE DESTINATIONS (Views)
			-- These define exactly how each type looks
			views = {
				-- RED VIEW (Error)
				mini_error = {
					backend = "mini",
					relative = "editor",
					align = "message-right",
					timeout = 5000,
					reverse = true,
					position = { row = "30%", col = "100%" },
					size = { width = "auto", height = 3, max_height = 10 },
					format = { "{message}" },
					border = {
						style = "rounded",
						padding = { 0, 1 },
						text = { top = "   Error  " },
					},
					win_options = {
						winblend = 0,
						winhighlight = {
							Normal = "Normal",
							FloatBorder = "DiagnosticError", -- Border Color (Red)
							FloatTitle = "DiagnosticError", -- Title Text Color (Red)
						},
					},
				},

				-- YELLOW VIEW (Warning)
				mini_warn = {
					backend = "mini",
					relative = "editor",
					align = "message-right",
					timeout = 4000,
					reverse = true,
					position = { row = "30%", col = "100%" },
					size = { width = "auto", height = 3, max_height = 10 },
					format = { "{message}" },
					border = {
						style = "rounded",
						padding = { 0, 1 },
						text = { top = "  Warning " },
					},
					win_options = {
						winblend = 0,
						winhighlight = {
							Normal = "Normal",
							FloatBorder = "DiagnosticWarn", -- Border Color (Yellow)
							FloatTitle = "DiagnosticWarn", -- Title Text Color (Yellow)
						},
					},
				},

				-- BLUE VIEW (Info)
				mini_info = {
					backend = "mini",
					relative = "editor",
					align = "message-right",
					timeout = 3000,
					reverse = true,
					position = { row = "30%", col = "100%" },
					size = { width = "auto", height = 3, max_height = 10 },
					format = { "{message}" },
					border = {
						style = "rounded",
						padding = { 0, 1 },
						text = { top = "  Info " },
					},
					win_options = {
						winblend = 0,
						winhighlight = {
							Normal = "Normal",
							FloatBorder = "DiagnosticInfo", -- Border Color (Blue)
							FloatTitle = "DiagnosticInfo", -- Title Text Color (Blue)
						},
					},
				},

				-- TEAL/GRAY VIEW (Hint)
				mini_hint = {
					backend = "mini",
					relative = "editor",
					align = "message-right",
					timeout = 3000,
					reverse = true,
					position = { row = "30%", col = "100%" },
					size = { width = "auto", height = 3, max_height = 10 },
					format = { "{message}" },
					border = {
						style = "rounded",
						padding = { 0, 1 },
						text = { top = "  Hint " },
					},
					win_options = {
						winblend = 0,
						winhighlight = {
							Normal = "Normal",
							FloatBorder = "DiagnosticHint", -- Border Color (Teal/Gray)
							FloatTitle = "DiagnosticHint", -- Title Text Color (Teal/Gray)
						},
					},
				},

				-- Command Mode Input Location
				cmdline_popup = {
					position = {
						row = "10%",
						col = "50%",
					},
				},
				-- LSP Loading Location
				mini = {
					position = {
						row = "98%",
						col = "0%",
					},
				},
			},

			-- 3. DEFAULTS
			-- Fallbacks if a specific route above is missed
			messages = {
				enabled = true,
				view = "mini_info",
				view_error = "mini_error",
				view_warn = "mini_warn",
			},
		})
	end,
}
