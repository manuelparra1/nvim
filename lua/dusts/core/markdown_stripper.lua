-- ~/.config/nvim/lua/markdown-utils.lua
local M = {}

M.strip_formatting = function()
	-- Save cursor position
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	-- Remove horizontal rules (---)
	vim.cmd([[%s/---\n//ge]])

	-- Remove bold formatting from headers
	vim.cmd([[%s/^\(#\{1,5\}\) \*\*\(.*\)\*\*/\1 \2/ge]])

	-- Remove formatting from quoteblock
	vim.cmd([[%s/^> \*\{1,2\}\(.*\)\*\{1,2\}/> \1/ge]])

	-- Restore cursor position
	vim.api.nvim_win_set_cursor(0, cursor_pos)

	print("Markdown formatting stripped!")
end

return M
