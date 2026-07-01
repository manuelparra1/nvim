local opt = vim.opt -- for conciseness

-- line numbers
opt.relativenumber = true -- show relative line numbers
opt.number = true -- shows absolute line number on cursor line (when relative number is on)

-- Search Recursively
vim.opt.path:append("**")

-- File Type Autocompletion
vim.filetype.plugin = 1
opt.omnifunc = "syntaxcomplete#Complete"

-- vim motions
opt.nrformats:append("alpha") -- treat numbers with letters as numbers (e.g., 10a -> 10)

-- tabs & indentation
opt.tabstop = 4 -- 2 spaces for tabs (prettier default)
opt.shiftwidth = 4 -- 2 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

-- line wrapping
opt.wrap = true -- disable line wrapping
vim.opt.linebreak = true -- Wraps at words, not in the middle of a word
-- opt.breakindent = true -- indent wrapped lines
-- opt.showbreak = "↪ " -- show a character at the start of wrapped lines

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- cursor line
opt.cursorline = true -- highlight the current cursor line

-- appearance

-- turn on termguicolors for nightfly colorscheme to work
-- (have to use with iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- turn off swapfile
opt.swapfile = false

-- command mode status height
-- opt.cmdheight = 0

-- Filetype Detection for Network Configs
vim.filetype.add({
	extension = {
		cisco = "cisco",
		ios = "cisco",
		nxos = "cisco",
		exos = "exos",
	},
	filename = {
		["running-config"] = "cisco",
		["startup-config"] = "cisco",
	},
	pattern = {
		[".*%.cisco"] = "cisco",
		[".*%.exos"] = "exos",
	},
})

-- Register the 'bash' parser to be used for 'exos' files
vim.treesitter.language.register("bash", "exos")

-- Make Homebrew tools visible to Neovim on macOS
if vim.loop.os_uname().sysname == "Darwin" then
	vim.env.PATH = "/opt/homebrew/bin:/usr/local/bin:" .. vim.env.PATH
end
