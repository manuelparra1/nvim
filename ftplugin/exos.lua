-- ~/.config/nvim/ftplugin/exos.lua

-- 1. Set specific comment strings (EXOS uses # just like bash)
vim.bo.commentstring = "# %s"

-- 2. Add custom keywords for syntax highlighting
-- This leverages Vim's regex syntax engine on top of the Treesitter bash base.
-- We explicitly match EXOS command words and link them to a highlight group (Statement).
vim.cmd([[
  syntax keyword ExosCommand configure create delete enable disable show unconfigure
  highlight link ExosCommand Statement
]])

-- 3. Set specific indentation rules (EXOS configs often don't use tabs)
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
