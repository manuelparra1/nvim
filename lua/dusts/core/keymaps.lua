-- /home/dusts/.config/nvim/lua/dusts/core/keymaps.lua

local utils = require("dusts.core.utils")
local keymap = vim.keymap -- for conciseness
vim.g.mapleader = " "

-- Note: Ideally, this option belongs in options.lua, but it's fine here for context
vim.opt.nrformats:append("alpha")

-- =============================================================================
-- General Keymaps
-- =============================================================================

-- Scroll Better
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

-- Exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
keymap.set("v", "jkj", "<Esc>", { desc = "Exit visual mode" }) -- You had this twice, kept one

-- Clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Delete single char without copying to register
keymap.set("n", "x", '"_x')

-- Window Split Navigation
keymap.set("n", "<leader>k", "<C-w>k", { desc = "Move to upper split" })
keymap.set("n", "<leader>j", "<C-w>j", { desc = "Move to lower split" })
keymap.set("n", "<leader>h", "<C-w>h", { desc = "Move to left split" })
keymap.set("n", "<leader>l", "<C-w>l", { desc = "Move to right split" })

-- Black Hole Register Operations (Don't yank deleted text)
keymap.set("n", "ciw", '"_ciw')
keymap.set("n", 'ci"', '"_ci"')
keymap.set("n", "diw", '"_diwh')
keymap.set("n", 'di"', '"_di"h')
keymap.set("n", "dd", '"_dd')

-- Visual Mode: Delete matching chars
keymap.set("x", "<leader>x", 'y:%s/<C-R>"//g<CR>', { desc = "Delete all matching characters" })

-- =============================================================================
-- Utility Functions (Powered by dusts.core.utils)
-- =============================================================================

-- 1. Markdown Stripper
-- Normal Mode (Whole File)
keymap.set("n", "<leader>mss", utils.strip_formatting, {
	desc = "Strip markdown formatting (File)",
	silent = true,
})

-- Visual Mode (Selected Range)
keymap.set("v", "<leader>mss", function()
	utils.strip_formatting()
end, {
	desc = "Strip markdown formatting (Selection)",
	silent = true,
})

-- 2. Title Case (Visual Mode)
keymap.set("v", "<Leader>T", function()
	utils.title_case_visual()
end, { noremap = true, silent = true, desc = "Convert to Title Case" })

-- 3. Quick Spell Correct (Visual Mode)
-- FIX: Mode ("v") comes first, then Key ("<leader>ss"), then the Function.
keymap.set("v", "<leader>ss", function()
	utils.quick_spell_correct()
end, { noremap = true, silent = true, desc = "Quick Spell Correct" })

-- 4. Lettered Lists (A. B. C.)
keymap.set("v", "<leader>aa", function()
	utils.create_list_visual()
end, { desc = "Create lettered list from visual selection" })

keymap.set("n", "<leader>aa", function()
	utils.create_list_paragraph()
end, { desc = "Create lettered list from current paragraph" })

-- 5. Insert Date
keymap.set("n", "<leader>id", function()
	utils.insert_date()
end, { desc = "Insert Date" })

keymap.set("i", "<C-i>d", function()
	utils.insert_date()
end, { desc = "Insert Date" })

-- =============================================================================
-- External Utility Keybinds / Keymaps
-- =============================================================================
-- vim.keymap.set('n', '<leader>tp', function()
--     local file_path = vim.fn.expand('%:p')
--     local cmd = "typora"
--
--     -- 1. Check if the file is actually Markdown
--     if vim.bo.filetype ~= "markdown" then
--         vim.notify("Current file is not Markdown", vim.log.levels.WARN)
--         return
--     end
--
--     -- 2. Check if the Typora executable exists in the PATH
--     if vim.fn.executable(cmd) == 1 then
--         vim.fn.jobstart({cmd, file_path}, {detach = true})
--         vim.notify("Opening in Typora...", vim.log.levels.INFO)
--     else
--         -- 3. Detailed error message if Typora is missing
--         vim.notify(
--             "Error: 'typora' not found in PATH.\nCheck ~/.local/bin or your symlink.",
--             vim.log.levels.ERROR,
--             { title = "External Utility Missing" }
--         )
--     end
-- end, { desc = "Open markdown in Typora with error check" })
