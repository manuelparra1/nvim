return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				path_display = { "truncate " },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
		})

		telescope.load_extension("fzf")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
		--see all LSP Diagnostics
		keymap.set("n", "<leader>fD", "<cmd>Telescope diagnostics<cr>", { desc = "Fuzzy find diagnostics in cwd" })
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
		keymap.set("n", "<leader>fu", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })

		-- Home directory searches
		keymap.set(
			"n",
			"<leader>gh",
			':lua require("telescope.builtin").live_grep({ cwd = os.getenv("HOME") })<CR>',
			{ desc = "Find string in home directory files" }
		)
		keymap.set(
			"n",
			"<leader>fd",
			':lua require("telescope.builtin").find_files({ cwd = os.getenv("HOME") })<CR>',
			{ desc = "Fuzzy find files in home directory" }
		)

		-- Obsidian notes searches
		keymap.set(
			"n",
			"<leader>go",
			':lua require("telescope.builtin").live_grep({ cwd = vim.fn.expand("~") .. "/aston/Notes/Obsidian/aston/" })<CR>',
			{ desc = "Find string in Obsidian notes directory" }
		)
		keymap.set(
			"n",
			"<leader>fo",
			':lua require("telescope.builtin").find_files({ cwd = vim.fn.expand("~") .. "/aston/Notes/Obsidian/aston/" })<CR>',
			{ desc = "Fuzzy find files in Obsidian notes directory" }
		)

		local builtin = require("telescope.builtin")

		-- === NEOVIM CONFIGS (Target: n) ===
		-- 1. Find File in Neovim
		-- Mnemonic: [f]ind [n]eovim
		keymap.set("n", "<leader>fn", function()
			builtin.find_files({ cwd = vim.fn.stdpath("config") })
		end, { desc = "Find Neovim Config Files" })

		-- 2. Grep Content in Neovim
		-- Mnemonic: [g]rep [n]eovim
		keymap.set("n", "<leader>gn", function()
			builtin.live_grep({ cwd = vim.fn.stdpath("config") })
		end, { desc = "Grep inside Neovim Config" })

		-- === GLOBAL CONFIGS (Target: c) ===

		-- 3. Find File in .config
		-- Mnemonic: [f]ind [c]onfigs
		keymap.set("n", "<leader>fc", function()
			builtin.find_files({
				cwd = vim.fn.expand("~/.config/"),
				hidden = true, -- Show hidden dotfiles (like .config/i3/config)
			})
		end, { desc = "Find Common Config Files" })

		-- 4. Grep Content in .config
		-- Mnemonic: [g]rep [c]onfigs
		keymap.set("n", "<leader>gc", function()
			builtin.live_grep({
				cwd = vim.fn.expand("~/.config/"),
				-- This is required to make 'rg' search inside hidden folders
				additional_args = function(args)
					return vim.list_extend(args, { "--hidden" })
				end,
			})
		end, { desc = "Grep inside Common Configs" })
	end,
}
