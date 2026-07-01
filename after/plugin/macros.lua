-- In normal, modifiable file buffers, ensure 'q' isn’t stolen
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		if vim.bo.buftype == "" and vim.bo.modifiable then
			-- remove any buffer-local 'q' mapping that a plugin may have set
			pcall(vim.keymap.del, "n", "q", { buffer = 0 })
		end
	end,
})

vim.api.nvim_create_user_command("WhyNoQ", function()
	print("buftype=" .. (vim.bo.buftype or "<nil>") .. ", modifiable=" .. tostring(vim.bo.modifiable))
	vim.cmd("verbose nmap q")
end, {})
