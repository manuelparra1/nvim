return {
	-- ~/.config/nvim/lua/dusts/plugins/llm.lua
	"melbaldove/llm.nvim",
	dependencies = { "nvim-neotest/nvim-nio", "nvim-lua/plenary.nvim" },
	config = function()
		local llm = require("llm")

		-- Import modularized components
		local prompts = require("dusts.core.llm_prompts")
		local services = require("dusts.core.llm_services")
		local logic = require("dusts.core.llm_logic")
		local keymaps = require("dusts.core.llm_keymaps")

		-- 1. Base Setup
		llm.setup({
			system_prompt = prompts.note_system_prompt,
			system_prompt_replace = prompts.system_prompt_replace,
			services = services,
		})

		-- 2. Inject Custom Logic
		-- This attaches the custom functions (prompt_selection_only, etc) to the 'llm' object
		logic.setup(llm, services, prompts)

		-- 3. Initialize Keybindings
		keymaps.setup(llm, prompts)
	end,
}
