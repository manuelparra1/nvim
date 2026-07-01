local utils = require("dusts.core.utils")

-- Group for Obsidian Helpers
local obsidian_group = vim.api.nvim_create_augroup("ObsidianHelpers", { clear = true })

vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = "*.md",
	group = obsidian_group,
	callback = function(args)
		-- 1. Setup Clean Citations Command & Keybind
		vim.api.nvim_buf_create_user_command(args.buf, "CleanMarkdownCitations", utils.clean_markdown_citations, {})
		vim.keymap.set("n", "<leader>mx", ":CleanMarkdownCitations<CR>", {
			buffer = args.buf,
			silent = true,
			desc = "Clean Citations",
		})

		-- 2. Setup Obsidian LLM Tagging (Only in your vault)
		local path = vim.api.nvim_buf_get_name(args.buf)
		if path:find("/Notes/Obsidian/aston/", 1, true) then
			vim.keymap.set("n", "<leader>to", function()
				utils.generate_and_apply_tags()
			end, { buffer = args.buf, desc = "Obsidian: Generate Tags" })
		end

		-- 3. Open Current Markdown File in Typora Keybind / Keymap
		vim.keymap.set("n", "<leader>tp", utils.open_in_typora, {
			buffer = args.buf, -- Only maps this key for this specific buffer
			desc = "Open in Typora (Fullscreen)",
		})
	end,
})
