return {
	"mfussenegger/nvim-lint",
	-- Only load the plugin for these specific filetypes
	ft = { "markdown", "lua", "python", "cpp", "html", "css" },
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			markdown = { "markdownlint" },
			lua = { "selene" },
			python = { "flake8" },
			cpp = { "cpplint" },
			html = { "djlint" },
			css = { "stylelint" },
		}

		-- 1. Access the markdownlint configuration
		local markdownlint = lint.linters.markdownlint

		-- 2. Append the disable argument for MD013 (Line Length)
		markdownlint.args = {
			"--disable",
			"MD013",
			"--", -- Required to separate flags from the filename
		}
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				-- Only run linting if the current filetype has a linter configured
				local ft = vim.bo.filetype
				if lint.linters_by_ft[ft] then
					lint.try_lint()
				end
			end,
		})
	end,
}
