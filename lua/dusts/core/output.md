# Combined Lua Files

## `markdown_stripper.lua`

---

```lua
-- ~/.config/nvim/lua/dusts/core/markdown_stripper.lua
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
```

## `llm_logic.lua`

---

```lua
-- ~/.config/nvim/lua/dusts/core/llm_logic.lua
local M = {}
local Job = require("plenary.job")

-- =============================================================================
-- Local Helper Functions
-- =============================================================================

local function get_comment_syntax(ft)
	local comment_markers = {
		lua = "--",
		python = "#",
		cisco = "!",
		javascript = "//",
		typescript = "//",
		java = "//",
		cpp = "//",
		c = "//",
		rust = "//",
		go = "//",
		markdown = "",
		text = "",
	}
	local marker = comment_markers[ft]
	if marker == nil then
		marker = "#"
	end
	return marker
end

local function get_chat_prefix(ft, comment_syntax)
	local chat_token = "??>"
	if ft == "markdown" or ft == "text" or ft == "" then
		return chat_token .. " "
	end
	return comment_syntax .. " " .. chat_token .. " "
end

local function parse_buffer_chat(visual_lines, user_prefix, comment_syntax)
	local messages = {}
	local current_role = nil
	local current_content = {}
	local current_reasoning = {}
	local is_thinking = false
	local context_lines = {} -- NEW
	local first_user_seen = false -- NEW

	local comment_prefix = comment_syntax
	if comment_prefix ~= "" then
		comment_prefix = comment_prefix .. " "
	end

	local function save_message()
		if #current_content > 0 or #current_reasoning > 0 then
			local msg = { role = current_role, content = table.concat(current_content, "\n") }
			if #current_reasoning > 0 then
				msg.reasoning = table.concat(current_reasoning, "\n")
			end
			table.insert(messages, msg)
			current_content = {}
			current_reasoning = {}
		end
	end

	for _, line in ipairs(visual_lines) do
		local trimmed_line = vim.trim(line)
		local is_user_line = vim.startswith(trimmed_line, user_prefix)

		-- NEW: everything before the first ??> is context, not an assistant turn
		if not first_user_seen then
			if is_user_line then
				first_user_seen = true
				current_role = "user"
			else
				table.insert(context_lines, line)
				goto continue
			end
		end

		if is_user_line and current_role ~= "user" then
			save_message()
			current_role = "user"
			is_thinking = false
		elseif not is_user_line and trimmed_line ~= "" and current_role ~= "assistant" then
			save_message()
			current_role = "assistant"
		end

		if current_role == "user" then
			local stripped_line = line:gsub("^%s*" .. vim.pesc(user_prefix), "")
			table.insert(current_content, stripped_line)
		elseif current_role == "assistant" then
			if line:match("<think>") then
				is_thinking = true
			elseif line:match("</think>") then
				is_thinking = false
			elseif is_thinking then
				local stripped_thought = line
				if comment_prefix ~= "" then
					stripped_thought = line:gsub("^%s*" .. vim.pesc(comment_prefix), "")
				end
				table.insert(current_reasoning, stripped_thought)
			else
				table.insert(current_content, line)
			end
		end

		::continue::
	end

	save_message()

	-- NEW: prepend context lines to the first user message
	if #context_lines > 0 and #messages > 0 and messages[1].role == "user" then
		local context = table.concat(context_lines, "\n")
		messages[1].content = vim.trim(context .. "\n" .. messages[1].content)
	end

	if #messages == 0 then
		table.insert(messages, { role = "user", content = table.concat(visual_lines, "\n") })
	end

	return messages
end

-- NEW: Convert parsed chat history to OpenAI Responses API input format
local function history_to_responses_input(instructions, parsed_history)
	local input = {
		{
			role = "developer",
			content = {
				{ type = "input_text", text = instructions },
			},
		},
	}
	for _, msg in ipairs(parsed_history) do
		-- user messages use input_text, assistant messages use output_text
		local content_type = msg.role == "assistant" and "output_text" or "input_text"
		table.insert(input, {
			role = msg.role,
			content = {
				{ type = content_type, text = msg.content },
			},
		})
	end
	return input
end

local function process_data_lines(line, process_data, state)
	local json = line:match("^data: (.+)$")
	if json then
		if json == "[DONE]" then
			-- NEW: If the model finishes but never sent text, gracefully inform the user
			if state and not state.first_chunk_received then
				vim.schedule(function()
					state.first_chunk_received = true
					vim.api.nvim_buf_set_lines(
						0,
						state.line - 1,
						state.line,
						false,
						{ "-- AI found no missing elements to generate." }
					)
				end)
			end
			return true
		end
		local ok, data = pcall(vim.json.decode, json)
		if ok and data then
			vim.schedule(function()
				pcall(vim.cmd, "undojoin")
				process_data(data)
			end)
		end
	end
	return false
end

-- CHANGED: second parameter is now api_type instead of service name
local function process_sse_response(buffer, api_type, state)
	local comment_syntax = state.comment_syntax

	for line in string.gmatch(buffer, "[^\r\n]+") do
		process_data_lines(line, function(data)
			local raw_content = ""
			local is_reasoning_chunk = false

			-- 1. Stream Parsing — branched by api_type
			if api_type == "responses" then
				-- NEW: OpenAI Responses API streaming format
				if data.type == "response.output_text.delta" and type(data.delta) == "string" then
					raw_content = data.delta
				elseif data.type == "response.reasoning_summary_text.delta" and type(data.delta) == "string" then
					raw_content = data.delta
					is_reasoning_chunk = true
				end
			elseif api_type == "anthropic" then
				-- UNCHANGED: Anthropic Messages API streaming format
				if data.type == "content_block_delta" and data.delta then
					if data.delta.type == "text_delta" and type(data.delta.text) == "string" then
						raw_content = data.delta.text
					elseif data.delta.type == "thinking_delta" and type(data.delta.thinking) == "string" then
						raw_content = data.delta.thinking
						is_reasoning_chunk = true
					end
				end
			else
				-- UNCHANGED: Standard chat completions (OpenRouter, Groq, Cerebras, Mistral, etc.)
				if data.choices and data.choices[1] and data.choices[1].delta then
					local delta = data.choices[1].delta

					if delta.reasoning_details and type(delta.reasoning_details) == "table" then
						for _, detail in ipairs(delta.reasoning_details) do
							if detail.type == "reasoning.text" and type(detail.text) == "string" then
								raw_content = raw_content .. detail.text
								is_reasoning_chunk = true
							end
						end
					elseif delta.reasoning and type(delta.reasoning) == "string" then
						raw_content = delta.reasoning
						is_reasoning_chunk = true
					elseif delta.content and type(delta.content) == "string" then
						raw_content = delta.content
					end
				end
			end

			-- Safety guard
			if type(raw_content) ~= "string" or raw_content == "" then
				return
			end

			-- 2. Buffer Formatting (UNCHANGED)
			local formatted_content = ""
			if not state.is_currently_thinking and is_reasoning_chunk then
				state.is_currently_thinking = true
				formatted_content = "\n\n"
					.. comment_syntax
					.. "<think>\n"
					.. comment_syntax
					.. raw_content:gsub("\n", "\n" .. comment_syntax)
			elseif state.is_currently_thinking and is_reasoning_chunk then
				formatted_content = raw_content:gsub("\n", "\n" .. comment_syntax)
			elseif state.is_currently_thinking and not is_reasoning_chunk then
				state.is_currently_thinking = false
				formatted_content = "\n\n" .. comment_syntax .. "</think>\n\n" .. raw_content
			else
				formatted_content = raw_content
			end

			-- 3. Write to Buffer (UNCHANGED)
			if not state.first_chunk_received then
				state.first_chunk_received = true
				vim.api.nvim_buf_set_lines(0, state.line - 1, state.line, false, {})
				state.line = state.line - 1
			end

			local combined = (state.current_content or "") .. formatted_content
			local content_lines = vim.split(combined, "\n", { plain = true })

			vim.api.nvim_buf_set_lines(0, state.line, state.line + 1, false, { content_lines[1] })
			if #content_lines > 1 then
				for i = 2, #content_lines do
					vim.api.nvim_buf_set_lines(0, state.line + i - 1, state.line + i - 1, false, { content_lines[i] })
				end
				state.line = state.line + #content_lines - 1
				state.current_content = content_lines[#content_lines]
			else
				state.current_content = content_lines[1]
			end
			vim.api.nvim_win_set_cursor(0, { state.line + 1, #state.current_content })
		end, state)
	end
end

-- =============================================================================
-- Main Setup Function
-- =============================================================================
function M.setup(llm, services, prompts)
	function llm.prompt_selection_only(opts)
		local replace = opts.replace
		local service = opts.service
		local visual_lines = {}
		local mode = vim.api.nvim_get_mode().mode
		local selection_end_row

		if mode == "v" or mode == "V" or mode == "\22" then
			local start_pos = vim.fn.getpos("v")
			local end_pos = vim.fn.getpos(".")
			if start_pos[2] == 0 or end_pos[2] == 0 then
				return
			end
			if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
				start_pos, end_pos = end_pos, start_pos
			end
			selection_end_row = end_pos[2]

			if mode == "V" then
				for lnum = start_pos[2], end_pos[2] do
					table.insert(visual_lines, vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1])
				end
			else
				if start_pos[2] == end_pos[2] then
					local line = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, start_pos[2], false)[1]
					table.insert(visual_lines, string.sub(line, start_pos[3], end_pos[3]))
				else
					for lnum = start_pos[2], end_pos[2] do
						local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
						if lnum == start_pos[2] then
							table.insert(visual_lines, string.sub(line, start_pos[3]))
						elseif lnum == end_pos[2] then
							table.insert(visual_lines, string.sub(line, 1, end_pos[3]))
						else
							table.insert(visual_lines, line)
						end
					end
				end
			end
		else
			local start_pos = vim.fn.getpos("'<")
			local end_pos = vim.fn.getpos("'>")
			if start_pos[2] == 0 or end_pos[2] == 0 then
				return
			end
			selection_end_row = end_pos[2]
			local success, result =
				pcall(vim.api.nvim_buf_get_text, 0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], {})
			if success then
				visual_lines = result
			end
		end

		if not visual_lines or #visual_lines == 0 then
			print("No selection found")
			return
		end

		local found_service = services[service]
		if not found_service then
			print("Invalid service: " .. service)
			return
		end

		-- NEW: resolve api_type from service config
		local api_type = found_service.api_type or "chat"

		local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
		local c_syntax = get_comment_syntax(ft)
		local u_prefix = get_chat_prefix(ft, c_syntax)

		-- NEW: Check for bypass flag. If true, treat selection as one raw document.
		local parsed_history
		if opts.is_document_prompt then
			parsed_history = { { role = "user", content = table.concat(visual_lines, "\n") } }
		else
			parsed_history = parse_buffer_chat(visual_lines, u_prefix, c_syntax)
		end

		local sse_state = {
			first_chunk_received = false,
			is_currently_thinking = false,
			current_content = "",
			line = 0,
			comment_syntax = c_syntax ~= "" and (c_syntax .. " ") or "",
		}

		if replace then
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("cThinking...", true, true, true), "v", false)
			sse_state.line = vim.api.nvim_win_get_cursor(0)[1] - 1
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
			vim.defer_fn(function()
				-- CHANGED: Added an extra "" to the table so the cleanup script leaves one behind
				vim.api.nvim_buf_set_lines(0, selection_end_row, selection_end_row, false, { "", "", "Thinking..." })
				-- CHANGED: Shifted the state line down by 1 to account for the new line
				sse_state.line = selection_end_row + 2
				vim.api.nvim_win_set_cursor(0, { sse_state.line + 1, 0 })
			end, 50)
		end

		local url = found_service.url
		local api_key_name = found_service.api_key_name
		local model = found_service.model
		local api_key = api_key_name and os.getenv(api_key_name)
		local data = {}
		local instructions = opts.system_prompt or prompts.note_system_prompt

		-- =====================================================================
		-- Build Payload — branched by api_type
		-- =====================================================================
		if api_type == "responses" then
			-- NEW: OpenAI Responses API format
			data = {
				model = model,
				stream = true,
				store = false,
				input = history_to_responses_input(instructions, parsed_history),
				text = {
					format = { type = "text" },
				},
			}
			if opts.verbosity then
				data.text.verbosity = opts.verbosity
			end
			if opts.reasoning_effort then
				data.reasoning = {
					effort = opts.reasoning_effort,
					summary = "auto",
				}
			end
			if opts.temperature then
				data.temperature = opts.temperature
			end
			if opts.max_tokens then
				data.max_output_tokens = opts.max_tokens
			end
		elseif api_type == "anthropic" then
			-- UNCHANGED
			data = {
				model = model,
				system = instructions,
				messages = parsed_history,
				max_tokens = opts.max_tokens or 8192,
				stream = true,
			}
			if opts.reasoning == "true" or opts.reasoning_effort then
				data.thinking = { type = "enabled", budget_tokens = 4096 }
			end
		elseif
			service == "mistral"
			or service == "ministral"
			or service == "nemostral"
			or service == "cerebras" -- ADDED: Cerebras uses top-level reasoning_effort like Mistral
		then
			data = {
				model = model,
				stream = true,
				max_tokens = opts.max_tokens,
				temperature = opts.temperature or 0.7,
				messages = { { role = "system", content = instructions } },
			}
			for _, msg in ipairs(parsed_history) do
				table.insert(data.messages, msg)
			end

			if opts.reasoning == "true" or opts.reasoning_effort then
				data.reasoning_effort = opts.reasoning_effort or "high"
			end
		else
			-- Generic chat completions (OpenRouter, Groq, DeepSeek, Grok, Ollama, etc.)
			data = {
				model = model,
				stream = true,
				max_tokens = opts.max_tokens,
				temperature = opts.temperature or 0.7,
				messages = { { role = "system", content = instructions } },
			}
			for _, msg in ipairs(parsed_history) do
				table.insert(data.messages, msg)
			end

			if opts.reasoning_tokens then
				data.reasoning = { max_tokens = opts.reasoning_tokens }
			elseif opts.reasoning_effort then
				data.reasoning = { effort = opts.reasoning_effort }
			elseif opts.reasoning == "true" then
				data.reasoning = { enabled = true }
			elseif opts.thinking == "off" then
				data.reasoning = { exclude = true }
			end
		end

		-- =====================================================================
		-- Build curl args
		-- =====================================================================
		local args = {
			"-N",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-d",
			vim.json.encode(data),
		}

		if api_key then
			if found_service.headers then
				for k, v in pairs(found_service.headers) do
					table.insert(args, "-H")
					table.insert(args, k .. ": " .. v)
				end
			end

			-- CHANGED: check api_type instead of service name
			if api_type == "anthropic" then
				table.insert(args, "-H")
				table.insert(args, "x-api-key: " .. api_key)
				table.insert(args, "-H")
				table.insert(args, "anthropic-version: 2023-06-01")
			else
				table.insert(args, "-H")
				table.insert(args, "Authorization: Bearer " .. api_key)
			end
		end

		table.insert(args, url)

		local current_active_job = Job:new({
			command = "curl",
			args = args,
			on_stdout = function(_, out)
				if out and out ~= "" then
					-- CHANGED: pass api_type instead of service name
					process_sse_response(out, api_type, sse_state)
				end
			end,

			on_exit = function(j, return_val)
				vim.schedule(function()
					if not sse_state.first_chunk_received then
						-- Grab standard output; if it's an API error, it will be raw JSON here.
						local raw_output = table.concat(j:result(), "\n")
						local err_msg = "Error receiving response."

						-- Attempt to parse OpenRouter/API JSON errors
						if raw_output ~= "" then
							local ok, parsed = pcall(vim.json.decode, raw_output)
							if ok and parsed and parsed.error then
								err_msg = "API Error: " .. (parsed.error.message or vim.inspect(parsed.error))
							else
								err_msg = "API Error:\n" .. raw_output
							end
						end

						-- FIX: Split the error message into a table of strings without \n
						local err_lines = vim.split(err_msg, "\n", { plain = true })

						local line_content = vim.api.nvim_buf_get_lines(0, sse_state.line, sse_state.line + 1, false)[1]
						if line_content and line_content:match("Thinking%.%.%.") then
							vim.api.nvim_buf_set_lines(
								0,
								sse_state.line,
								sse_state.line + 1,
								false,
								err_lines -- Pass the safe table here
							)
						end
					end
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
				end)
			end,
		})
		current_active_job:start()
	end

	function llm.prompt_selection_only_append(opts)
		opts.replace = false
		llm.prompt_selection_only(opts)
	end
end

return M
```

## `init.lua`

---

```lua
-- ~/.config/nvim/init.lua
require("dusts.core.keymaps")
require("dusts.core.options")
require("dusts.core.autocmds")
```

## `autocmds.lua`

---

```lua
-- ~/.config/nvim/lua/dusts/core/autocmds.lua
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
```

## `keymaps.lua`

---

```lua
-- ~/.config/nvim/lua/dusts/core/keymaps.lua

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
```

## `llm_services.lua`

---

```lua
-- ===========================================================================
-- llm.nvim Plugin LLM Service Configuration
-- ===========================================================================
-- ~/.config/nvim/lua/dusts/core/llm_services.lua
return {
	openrouter = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		-- model = "arcee-ai/trinity-large-thinking",
		-- model = "meta-llama/llama-3.1-8b-instruct",
		-- ($0.02/$0.05)
		-- model = "nvidia/nemotron-3-super-120b-a12b:free",
		model = "",
		-- ($0.02/$0.04)
		api_key_name = "OPENROUTER_API_KEY",
	},
	anthropic = {
		url = "https://api.anthropic.com/v1/messages", -- FIXED: was /v1/chat/completions (doesn't exist)
		model = "claude-opus-4-7",
		api_key_name = "ANTHROPIC_API_KEY",
		api_type = "anthropic", -- NEW
	},
	gpt_5 = {
		url = "https://api.openai.com/v1/responses", -- FIXED: was /v1/chat/completions
		model = "gpt-5.4",
		-- 2x Price
		-- model = "gpt-5.5",
		api_key_name = "OPENAI_API_KEY",
		api_type = "responses", -- NEW
	},
	mimo = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "xiaomi/mimo-v2-flash",
		api_key_name = "OPENROUTER_API_KEY",
	},
	openai = {
		url = "https://api.openai.com/v1/responses", -- FIXED: was /v1/chat/completions
		model = "gpt-5.4-nano",
		api_key_name = "OPENAI_API_KEY",
		api_type = "responses", -- NEW
	},
	grok = {
		url = "https://api.x.ai/v1/chat/completions",
		model = "grok-4.3-latest",
		api_key_name = "GROK_API_KEY",
	},
	gemini = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "google/gemini-3.1-pro-preview",
		api_key_name = "OPENROUTER_API_KEY",
	},
	flash_lite = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "google/gemini-3.1-flash-lite-preview",
		api_key_name = "OPENROUTER_API_KEY",
	},
	flash = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "google/gemini-3-flash-preview",
		api_key_name = "OPENROUTER_API_KEY",
	},
	mimo_pro = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "xiaomi/mimo-v2-pro",
		api_key_name = "OPENROUTER_API_KEY",
	},
	stepfun = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "stepfun/step-3.5-flash:free",
		api_key_name = "OPENROUTER_API_KEY",
	},
	qwen3 = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "qwen/qwen3.5-flash-02-23",
		api_key_name = "OPENROUTER_API_KEY",
	},
	olmo = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "allenai/olmo-3.1-32b-think",
		api_key_name = "OPENROUTER_API_KEY",
	},
	cerebras = {
		url = "https://api.cerebras.ai/v1/chat/completions",
		model = "gpt-oss-120b",
		api_key_name = "CEREBRAS_API_KEY",
	},
	groq = {
		url = "https://api.groq.com/openai/v1/chat/completions",
		model = "openai/gpt-oss-120b",
		api_key_name = "GROQ_API_KEY",
	},
	z_ai = {
		url = "https://api.z.ai/api/paas/v4/chat/completions",
		model = "glm-5",
		api_key_name = "Z_API_KEY",
	},
	kimi_k2 = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "moonshotai/kimi-k2.5",
		api_key_name = "OPENROUTER_API_KEY",
	},
	minimax = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "minimax/minimax-m2.7",
		api_key_name = "OPENROUTER_API_KEY",
	},
	oss = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "openai/gpt-oss-20b",
		api_key_name = "OPENROUTER_API_KEY",
	},
	tiny_qwen3 = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "qwen/qwen3.5-9b",
		api_key_name = "OPENROUTER_API_KEY",
	},
	tiny_llama = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "meta-llama/llama-3.2-3b-instruct:free",
		api_key_name = "OPENROUTER_API_KEY",
	},
	deepcoder = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "agentica-org/deepcoder-14b-preview:free",
		api_key_name = "OPENROUTER_API_KEY",
	},
	gemma = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "google/gemma-4-31b-it",
		api_key_name = "OPENROUTER_API_KEY",
	},
	mistral = {
		url = "https://api.mistral.ai/v1/chat/completions",
		model = "mistral-small-latest",
		api_key_name = "MISTRAL_API_KEY",
	},
	ministral = {
		url = "https://api.mistral.ai/v1/chat/completions",
		model = "ministral-14b-latest",
		api_key_name = "MISTRAL_API_KEY",
	},
	nemostral = {
		url = "https://api.mistral.ai/v1/chat/completions",
		model = "open-mistral-nemo",
		api_key_name = "MISTRAL_API_KEY",
	},
	devstral = {
		url = "https://api.mistral.ai/v1/chat/completions",
		model = "devstral-small-latest",
		api_key_name = "MISTRAL_API_KEY",
	},
	codestral = {
		url = "https://codestral.mistral.ai/v1/chat/completions",
		model = "codestral-latest",
		api_key_name = "CODESTRAL_API_KEY",
	},
	nemotron = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "nvidia/nemotron-3-super-120b-a12b:free",
		api_key_name = "OPENROUTER_API_KEY",
	},
	nemotron_ultra = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "nvidia/llama-3.1-nemotron-ultra-253b-v1",
		api_key_name = "OPENROUTER_API_KEY",
	},
	deepseek = {
		url = "https://api.deepseek.com/v1/chat/completions",
		-- cost = 0.14/0.28
		model = "deepseek-v4-flash",
		-- cost = $1.74/$3.48 ($0.435/$0.87)
		-- model = "deepseek-v4-pro",
		api_key_name = "DEEPSEEK_API_KEY",
	},
	ollama_code = {
		url = "http://10.0.0.103:11434/v1/chat/completions",
		model = "qwen2.5-coder:14b",
		api_key_name = "OLLAMA_API_KEY",
	},
	ollama_notes = {
		url = "http://127.0.0.1:11434/v1/chat/completions",
		model = "qwen3:0.6b",
		api_key_name = "OLLAMA_API_KEY",
	},
}
```

## `options.lua`

---

```lua
-- ~/.config/nvim/lua/dusts/core/options.lua
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
```

## `llm_prompts.lua`

---

```````lua
-- ~/.config/nvim/lua/dusts/core/llm_prompts.lua
local M = {}

M.oreilly_prompt = [[
You are an expert technical editor assisting with markdown notes.
The user provides a text block containing context and a final instruction (starting with `>`).

# CRITICAL RULES (STRICT COMPLIANCE)
1. **NO ECHO:** Do NOT repeat, summarize, or output any part of the *previous* context.
2. **SCOPE:** Generate content ONLY for the very last instruction (the line starting with `>`).
3. **NO FLUFF:** Start directly with the header. No "Here is the comparison" conversational filler.

# VISUAL STRUCTURE (The "Textbook" Style)
1. **Complex Topics:** If a topic has multiple facets (e.g., Hardware + Software + Memory), divide the response into distinct subsections using `### Subheadings`.
2. **Tables:** ALWAYS use Markdown tables for comparisons. Never use list-based comparisons.
3. **Narrative First:** Always introduce a table with a short narrative paragraph explaining the context.
4. **The "Implication" Footer:** End complex sections with a single sentence starting with "Practical implication:" that explains *why* this matters to an engineer.

# FORMATTING STANDARDS
- **Lists:** Use simple bullets (`-`) only for specifications or steps. No "dictionary style" bold keys (`- **Term**: Def`).
- **Tone:** Professional, objective, technical.

Perform the requested task precisely based on the last `>` instruction.
]]

M.explain_it_peter_prompt = [[
You are an AI assistant helping with editing and formatting markdown notes.
Use the selected text as context.
Follow the last instruction (last line with `>`) which is comments
annotated with `>` which is a markdown quote block.
Perform the requested task precisely and concisely.
Generate valid content only.

Follow These Rules:
- Use best practice markdown syntax.
- Focus on providing exactly what the user asks for, nothing more.
- Do not include explanations, introductions, or additional content
  unless explicitly requested.
- Do not include prefixes like `//`,`--`, etc.
  or basically what amounts to comments in your response.
- Keep responses brief and that directly address the user's instruction.
- Use a conversational and friendly tone but that doesn't "talk down" to the user.
- Use a narrative form to explain yourself.
- Don't use any bullet points if possible.
- The goal is avoid the "AI/LLM wall of text" with bullet point heavy _outline_ structure.
- Use subheadings (e.g., `##`, `###`) when necessary to divide paragraphs
  for easy reading.

Having said that:

Can you make a narrative version of what the bullet points in the following section is trying to explain? With a conversational tone like a senior network engineer explaining it to a junior network engineer in a casual manner. Keep it under 1 paragraph (like 3 to 4 sentences at the most.

]]

M.lets_rock_peter = [[

You are an AI assistant helping with editing and formatting markdown notes.
Use the selected text as context.
Follow the last instruction (last line with `>`) which is comments
annotated with `>` which is a markdown quote block.
Perform the requested task precisely and concisely.
Generate valid content only.

Follow These Rules:
- Use best practice markdown syntax.
- Focus on providing exactly what the user asks for, nothing more.
- Do not include explanations, introductions, or additional content
  unless explicitly requested.
- Do not include prefixes like `//`,`--`, etc.
  or basically what amounts to comments in your response.
- Keep responses brief and that directly address the user's instruction.
- Use a conversational and friendly tone but that doesn't "talk down" to the user.
- Use a narrative form to explain yourself.
- Don't use any bullet points if possible.
- The goal is avoid the "AI/LLM wall of text" with bullet point heavy _outline_ structure.
- Use subheadings (e.g., `##`, `###`) when necessary to divide paragraphs
  for easy reading.

Having said that:

For the following provided text.

There is supposed to be a bullet point list with an introductory sentence. If there is no bullet point list can you make a simple one that captures the information that is being conveyed in the context data provided?

Can you make the the introductory sentence more detailed and fleshed out? If there isn't one can you generate one?

This is very important for the introductory sentence: the intro sentence only "sets the stage" for the provided bullet point list or context. It shouldn't be redundant in its information provided. When compared to the bullet point list or the original context the intro sentence shouldn't repeat itself to the information in the list or the provided context. The narrative version of the list which I will explain next shouldn't have similar text to the bullet lists or the intro sentence either.
After dealing with the intro sentence, can you also make a narrative version of what the bullet points in the following section in the provided context is trying to explain? Generate that narrative version if there is a list in the context, if not then skip it. For that narrative version of the bullet point list, can you generate it with a conversational tone like a senior network engineer explaining it to a junior network engineer in a casual manner. Keep it under 1 paragraph (like 3 to 4 sentences at the most.

]]

M.note_system_prompt = [[
You are an expert technical editor assisting with markdown notes.

# CRITICAL RULES (STRICT COMPLIANCE)
1. **NO ECHO:** Do NOT repeat, summarize, or output any part of the *previous* context.
2. **SCOPE:** Generate content ONLY for the very last instruction (the line starting with `>`).
3. **NO FLUFF:** Start directly with the header or answer. No "Here is the info" or conversational filler.
4. **Behavior:** When responding to the question.
   - Do not praise the user to avoid obsequious, ingratiating, syncophancic sounding responses.
   - Do not use prefixes to analogy responses like "Think of it like", "It's kind of like", etc.,
     but instead make it sound more natural when integrating the analogy.
5. **Short:** Keep responses short and to the point.
   - Use the least amount of information needed to answer the question.
   - Response should be under 1 paragraph.
   - Only if _absolutely_ needed to exceed the 1 paragraph,
     then use the additional response formatting rules below.
6. **Choice:** _Only if_ the user asks for more information about a prior response,
   as a follow-up, then expand on it and don't keep the response short, and use all the formatting rules below.
   - The user might say, something like "Can you explain that in more detail?", "What do you mean by x", etc.

# RESPONSE FORMATTING
1. **Primary Format:** Use **Subheadings (`###`)** and **Narrative Paragraphs**.
   - Do NOT use bullet points for general explanations. Write in clear, full sentences.
2. **Comparisons:** ALWAYS use a **Markdown Table** when comparing 3+ items, concepts, or topics.
3. **Lists:** Use simple bullet points (`-`) *only* if listing 3+ distinct specifications or steps.
   - *Constraint:* Keep bullets simple. No bold keys (`- **Key**: Val`).

4. **The Wrap-Up Section:** ALWAYS end the response with a standalone sentence (after a newline) that summarizes your response concisely and basically what it means of what you provided in simplified terms.
   - You should be able to metaphorically say "that's all it is" before or after your wrap-up statement

5. **Titles:** Do not add a heading, subheading, title, label, distinction, etc. for the wrap-up section.
   - That means no headings or subheadings like "## Wrap Up", "### Practical Implication",
     "### Wrap Up", etc.
   - That means do not use "The Practical Implication is that..."
   - That means do not use prefix to the sentence like "Practical implication:"

]]

M.system_prompt_replace = [[
Follow the instructions in the code comments annotated with `--`. Generate code only. Think step by step.
If you must speak, do so in comments annotated with `--`. Generate valid code only.
]]

M.youtube_transcript_cleaner_prompt = [[
Can you convert this Youtube video transcript into a readable form. Do this by splitting
into proper sentences and paragraphs using punctuation, capitalization, and new lines.
Do not rewrite this just add structure, so that it is easy to follow and flows well by
adding the punctuation, new lines, and paragraph splits.
]]

M.youtube_clean_transcript_summary_generator_prompt = [[
What was this video about? Can you distill the information in the video, maintaining the
original context and tone, while preserving all relevant details and including all
relevant information? Please keep all anecdotes, opinions, main ideas, points, and named
entities, and provide a brief summary of the video's main argument or narrative? Remove
mentions of sponsors, adds, and things like that. Please use structure that makes it easy
to digest with readability, and sections for explanations in simple language. Use best
practice markdown syntax. Can you add a "TLDR" section that summarizes this video in a
narrative form? Can you add additional details that you know from your training but
aren't mentioned and are important?
]]

M.code_system_prompt = [[

You are a code generation AI. Output only raw, executable code.
Rules:
1. NEVER use markdown formatting or backticks
2. NEVER wrap code in ``````
3. Output ONLY the exact code requested
4. Use the specified comment syntax for any necessary comments
5. Match the style of surrounding code
6. No explanations or text outside of code comments
7. No markdown, no formatting, just raw code
]]

M.title_spiel_prompt = [[
You are provided with markdown content.

Your task is to generate a title, subtitle, and spiel for the
document.

Instead of regenerating the entire document, check if any of the
following are missing and output only those missing elements
as separate markdown lines:

Do not add any headings, subheadings, titles, labels, distinctions, etc.

{{TOPIC}} is the main idea of the document which you will replace
this placeholder with the actual topic and ensure it flow well,
is easty to read, follow, digest, and grammatically correct.

1. **Title:** If there is no main title (a line starting with
`#` at the very top and beggining of the document), then
generate a concise title (under 5 words) that captures
the main idea which is the {{TOPIC}}.

2. **Subtitle:** If there is no subtitle (a blockquote line
starting with `>`) immediately after the annotated (#) title, then
generate a brief subtitle (under 8 words; which is annotated with `>` prefix)
that is based on the title and the main idea of the document's {{TOPIC}}.

3. **Spiel:** If there is no introductory spiel following the
subtitle(a sentence after the `>` blockquote), then
generate a one-sentence spiel. The spiel must be conversational
yet technical, with a professional tone suitable for an interview.
It should describe the main topic ({{TOPIC}}) along with its key
features and purpose—as if answering questions like
"what do you know about {{TOPIC}}", "what is {{TOPIC}}", or
"what have you worked with in relation to {{TOPIC}}".
Output only the missing elements without reproducing the rest of the content.
**Important** output the raw markdown. Do not encase in code blocks.

Here as the structure of the expected output templatized:

**Example:**
```text
# <Title>

> <Subtitle>

<One sentence spiel.>
```````

]]

M.course_generator_prompt = [[Can you generate a written version of this video course in the style of a
textbook using this video transcript. Please keep explanations, analogies,
metaphors, quizzes, etc, but tailor them to be readable in the textbook
style and written form with one difference which is a more natural, informal
style. For example organizing texts to be easily digestible and referenced
but include narrative style paragraphs as well.]]

M.clean_markdown_prompt = [[

1. **Remove Bold Sections:**
   Convert any bold title that are in lists that could be converted
   to standard practice markdown syntax sub-headings
   (e.g., `##`, `###`, etc)
2. **Concise Title:**
   If there is no main (`#`) title create one that is to the point
   (so as close to under 5 words as possible) and captures main idea
   of the notes. Any missing context will be covered by the main
   subtitle.
3. **The Main Subtitle:**
   if missing a main subtitle inside a blockquote (`>`) below the
   main title (inside a main heading `#`) create a short descriptive
   subtitle ( under 8 words) and place in markdown syntax blockquote
   `>` below the main title and above the "spiel".
4. **Spiel:**
   after the main subtitle (which is inside a blockquote `>`) create a
   new paragraph which will be the spiel using this structure:

- gather main topic from the notes
  {1 sentence (if possible) conversational, yet technical, for an
  interview, professional tone spiel of {{TOPIC}} and it's key features
  and purpose for them. (as if asked "what do you know about {{TOPIC}}",
  "What you worked with {{TOPIC}} or "what is {{TOPIC}}" then it would be
  possible to respond with this spiel as an answer to a probing question
  into my experience and job history}

5. **Original Content:**
   use original content provided but do not reword or summarize. If
   necessary restructure the content to improve readability with
   sub-headings and necessary organization typical of markdown syntax
   best practice.
6. **Improve Markdown Structure:**

- Ensure that the main title is a top-level header using `#`
- Use subheading levels (e.g., `##`, `###`) appropriately to
  structure the main body content.
- If necessary convert large lists and bullet points with long senteces
  into subsections with their own subheading to improve readability
- If there are multiple nested lists use standard practice markdown
  to organize into appriate sub-headings for readability

7. **Preserve Content Integrity:**
   Do not summarize, but do keep all text, descriptions, and lists,
   and format them using best-practice markdown (e.g., use block
   quotes for descriptive text when the language suggests it is
   giving a tip, quoting, or noting,etc).
   The main goal is to improve readability, create easy fast, and digestability,
   but not reword or remove content.
   ]]

M.clean_scraped_markdown_prompt = [[
You are provided with a markdown document generated from an HTML scraper.
Transform the document as follows:

1. **Remove Useless Navigation:**

- Delete any navigation content (e.g. table of contents, numbered lists, or
  links like "[Home](/)", "[PAN-OS](/content/techdocs/...)") that does not
  belong to the main content.

2. **Process Image References:**
   Remove all full image paths. For every image reference, extract only the base
   image file name and replace its path with a local destination (`./images/`).
   _Example:_
   `![Filter icon](/content/dam/techdocs/en_US/images/icons/css/filter.svg)`
   should become:
   `![](./images/filter.svg)`
   _Example 2:_
   `[![](./images/track_lab1.png "Track_Lab")](https://linkstate.wordpress.com/wp-content/uploads/2011/07/track_lab1.png)`
   should become:
   `![track_lab1.png](./images/track_lab1.png)`
3. **Improve Markdown Structure:**

- Ensure that the main title is a top-level header using `#`
- Use nested header levels (e.g., `##`, `###`) appropriately to structure the
  content.

4. **Preserve Content Integrity:**

- Do not summarize, but do keep all text, descriptions, and lists, and format
  them using best-practice markdown (e.g., use block quotes for descriptive
  text when the language suggests it is giving a tip, quoting, or noting,etc).

5. **Extra Clean-Up:**

- Remove author information, article date, about the author footer info.
  5a. **remove hardcoded new lines:**
- if paragraphs are cut off with new lines to wrap text please join into one line instead.
  **Important:** Do not remove or modify the final line that starts with `> Source:`.
  Ensure that this source attribution remains exactly as is at the bottom of the
  transformed markdown.
  ]]

M.clean_bad_yaml = [[

You will be provided with yaml like syntax text that needs to be transformed.
It is bad syntax for Obsidian. I have provided an exampl of good syntax that
Obsidian likes. Can you transform the bad syntax into the good syntax style?
Respond with just the bare text within the yaml codeblock and not the codeblock
syntax. That way this text is useable immediately from your response.

"Bad":

```yaml
---

id: layer-1-2-svi
aliases:

* SVI
* SVIs
  tags:
* network-engineering
* layer-1-2
* daily-learner
  title: SVI

---
```

"Good":

```yaml
---
id: layer-1-2-svi
aliases:
  - SVI
  - SVIs
tags:
  - network-engineering
  - layer-1-2
  - daily-learner
created: 2026-05-07T16:42:07
title: SVI
---
```

]]
return M

````

## `utils.lua`
---
```lua
local M = {}

-- ===================================================================
-- LOGGING HELPER
-- ===================================================================
local function log(log_file, message)
	local file = io.open(log_file, "a")
	if file then
		file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
		file:close()
	end
end

-- ===================================================================
-- MARKDOWN HELPERS
-- ===================================================================

-- 1. Markdown Stripper (Smart: Works for Visual or Whole File)
function M.strip_formatting()
	-- Save cursor position
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local start_line, end_line

	-- Check if we are in visual mode or were just in visual mode
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" then
		-- We are currently in visual mode, get the range
		start_line = vim.fn.line("v")
		end_line = vim.fn.line(".")
		-- Swap if backwards selection
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		-- Exit visual mode so we can edit
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
	else
		-- Normal mode: Do the whole file
		start_line = 1
		end_line = vim.fn.line("$")
	end

	-- Loop through the lines and strip formatting
	-- (We use a loop instead of %s so we can target specific ranges)
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

	for i, line in ipairs(lines) do
		-- 1. Remove Horizontal Rules (---)
		line = line:gsub("^%-%-%-%s*$", "")

		-- 2. Remove Bold/Italic markers (***text***, **text**, *text*)
		-- Note: We run this loop twice to handle nested cases like ***bolditalic***
		for _ = 1, 2 do
			line = line:gsub("%*%*%*(.-)%*%*%*", "%1") -- Bold+Italic
			line = line:gsub("%*%*(.-)%*%*", "%1") -- Bold
			line = line:gsub("%*(.-)%*", "%1") -- Italic
			-- Handle underscores too if you use them
			line = line:gsub("___(.-)___", "%1")
			line = line:gsub("__(.-)__", "%1")
			line = line:gsub("_(.-)_", "%1")
		end
		lines[i] = line
	end

	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
	vim.api.nvim_win_set_cursor(0, cursor_pos)
	print("Formatting stripped from lines " .. start_line .. " to " .. end_line)
end

-- 2. Clean Citations (Perplexity)
function M.clean_markdown_citations()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local filtered_lines = {}
	local ref_start_line = nil
	local in_code_block = false
	local i = 1

	-- Pass 1: Filter Footer
	while i <= #lines do
		local line = lines[i]
		if line:match("^```") then
			in_code_block = not in_code_block
		end

		-- Detect Perplexity Footer
		if
			not in_code_block
			and i + 2 <= #lines
			and line:match("^%-%-%-$")
			and lines[i + 2]:match("^Answer from Perplexity")
		then
			i = i + 3 -- Skip footer
		else
			if not ref_start_line and not in_code_block and (line:match("^%[%d+%]:") or line:match("^Citations:")) then
				ref_start_line = #filtered_lines + 1
			end
			table.insert(filtered_lines, line)
			i = i + 1
		end
	end

	-- Pass 2: Format Citations
	if not ref_start_line then
		ref_start_line = #filtered_lines + 1
	end
	for j = 1, #filtered_lines do
		if filtered_lines[j]:match("^```") then
			in_code_block = not in_code_block
		end

		if not in_code_block then
			if j < ref_start_line then
				-- Content: Fix superscripts
				local line = filtered_lines[j]
				line = line:gsub("%]%[", "] [")
				line = line:gsub("%[(%d+)%]", "<sup>[[%1]][%1]</sup>")
				line = line:gsub("</sup> <sup>", ", ")
				filtered_lines[j] = line
			else
				-- References: Fix formatting
				local line = filtered_lines[j]
				if line:match("^Citations:$") then
					filtered_lines[j] = ""
				else
					line = line:gsub("^(%[%d+%])([^:])", "%1:%2")
					filtered_lines[j] = line
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(0, 0, -1, false, filtered_lines)
	cursor_pos[1] = math.min(cursor_pos[1], #filtered_lines)
	pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
	print("Markdown citations cleaned up!")
end

-- 3. Open Current Markdown File with Typora
function M.open_in_typora()
	local file_path = vim.fn.expand("%:p")
	local file_name = vim.fn.expand("%:t")
	if file_path == "" then
		vim.notify("Buffer has no file path!", vim.log.levels.WARN)
		return
	end

	-- 1. Check if Typora exists
	if vim.fn.executable("typora") == 0 then
		vim.notify("Typora not found in PATH!", vim.log.levels.ERROR)
		return
	end

	-- 2. Improved i3 Detection for startx/TTY users
	-- We try to find the socket path directly if i3-msg fails initially
	local is_i3 = os.execute("i3-msg -t get_version >/dev/null 2>&1") == 0
	if not is_i3 then
		-- Try to manually grab the socket if we are in an X session
		local socket = io.popen("i3 --get-socketpath 2>/dev/null"):read("*a"):gsub("%s+", "")
		if socket ~= "" then
			vim.env.I3SOCK = socket
			is_i3 = true
		end
	end

	-- 3. Check for jq (needed for the "already open" check)
	local has_jq = vim.fn.executable("jq") == 1

	if is_i3 then
		-- i3 Logic (using the now-verified I3SOCK)
		local check_cmd = string.format(
			'i3-msg -t get_tree | jq -e \'.. | select(.window_properties? and .window_properties.class == "Typora" and (.window_properties.title | contains("%s")))\' > /dev/null',
			file_name
		)

		local is_open = has_jq and (os.execute(check_cmd) == 0)

		if is_open then
			vim.fn.jobstart(string.format('i3-msg \'[class="Typora" title="%s"] focus, fullscreen enable\'', file_name))
			vim.notify("Switching to existing Typora instance", vim.log.levels.INFO)
		else
			-- Launch + Force Fullscreen loop
			local script = string.format(
				[[
                export I3SOCK=$(i3 --get-socketpath)
                typora %s &
                for i in {1..20}; do
                    if i3-msg -t get_tree | grep -q '"class":"Typora"'; then
                        i3-msg "[class=\"Typora\"] focus, fullscreen enable" > /dev/null
                        break
                    fi
                    sleep 0.1
                done
            ]],
				vim.fn.shellescape(file_path)
			)

			vim.fn.jobstart({ "bash", "-c", script }, { detach = true })
			vim.notify("Launching Typora Fullscreen (i3)", vim.log.levels.INFO)
		end
	else
		-- Fallback for non-i3 systems
		vim.fn.jobstart({ "typora", file_path }, { detach = true })
		vim.notify("Non-i3 system detected. Opening normally.", vim.log.levels.INFO)
	end
end

-- ===================================================================
-- TEXT MANIPULATION
-- ===================================================================

function M.title_case_visual()
	local _, start_col = unpack(vim.fn.getpos("'<"), 2)
	local _, end_col = unpack(vim.fn.getpos("'>"), 2)
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")

	for line_num = start_line, end_line do
		local line = vim.fn.getline(line_num)
		local start = line_num == start_line and start_col or 1
		local end_pos = line_num == end_line and end_col or #line
		local selected = line:sub(start, end_pos)

		local titled = selected:gsub("(%a)(%w*)", function(first, rest)
			return first:upper() .. rest:lower()
		end)

		line = line:sub(1, start - 1) .. titled .. line:sub(end_pos + 1)
		vim.fn.setline(line_num, line)
	end
end

function M.quick_spell_correct()
	vim.cmd("set spell")
	vim.cmd("normal! gv") -- Reselect last visual
	local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
	local word = vim.fn.expand("<cword>")
	local suggestions = vim.fn.spellsuggest(word, 1)

	if #suggestions > 0 then
		vim.api.nvim_buf_set_text(0, line - 1, col - 1, line - 1, col + #word - 1, { suggestions[1] })
	else
		vim.notify("No suggestions found", vim.log.levels.INFO)
	end
	vim.cmd("set nospell")
end

-- ===================================================================
-- AI AUTO-TAGGING (Internal Helpers hidden)
-- ===================================================================
local function find_frontmatter(lines)
	if #lines == 0 or lines[1] ~= "---" then
		return nil
	end
	for i = 2, #lines do
		if lines[i] == "---" then
			local fm = {}
			for j = 2, i - 1 do
				table.insert(fm, lines[j])
			end
			return 1, i, fm
		end
	end
	return nil
end

local function remove_tags_and_get_pos(fm_lines)
	local cleaned = {}
	local pos = #fm_lines + 1
	local found = false
	local i = 1
	while i <= #fm_lines do
		if fm_lines[i]:match("^tags:") then
			if not found then
				pos = #cleaned + 1
				found = true
			end
			if fm_lines[i]:match("^tags:%s*$") then
				i = i + 1
				while i <= #fm_lines and fm_lines[i]:match("^%s*-") do
					i = i + 1
				end
			else
				i = i + 1
			end
		else
			table.insert(cleaned, fm_lines[i])
			i = i + 1
		end
	end
	return cleaned, pos
end

function M.generate_and_apply_tags()
	-- Dependencies
	local has_plenary, Job = pcall(require, "plenary.job")
	if not has_plenary then
		vim.notify("Plenary.nvim is not installed!", vim.log.levels.ERROR)
		return
	end

	-- Configuration
	local config = {
		api_key_env = "OPENROUTER_API_KEY",
		url = "https://openrouter.ai/api/v1/chat/completions",
		payload = { model = "mistralai/mistral-nemo", temperature = 0.1, max_tokens = 128 },
	}

	local api_key = os.getenv(config.api_key_env)
	if not api_key then
		vim.notify("API Key missing", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local _, fm_end, fm_lines = find_frontmatter(lines)
	fm_lines = fm_lines or {}

	-- Get content after frontmatter
	local content_start = (fm_end or 0) + 1
	local content = table.concat({ unpack(lines, content_start) }, "\n")

	if vim.trim(content) == "" then
		return
	end

	local prompt = [[
    Return only a single JSON object. No prose.
    Keys: subjectTags (Array), intentTags (Array). Total max 6 tags.
    subjectTags: Title Case. intentTags: lowercase, hyphen-separated.
    Note content:
    ]] .. content

	vim.notify("Generating tags...")

	config.payload.messages = { { role = "user", content = prompt } }
	config.payload.response_format = { type = "json_object" }

	Job:new({
		command = "curl",
		args = {
			"-s",
			config.url,
			"-H",
			"Authorization: Bearer " .. api_key,
			"-H",
			"Content-Type: application/json",
			"-d",
			vim.fn.json_encode(config.payload),
		},
		on_exit = vim.schedule_wrap(function(job, code)
			if code ~= 0 then
				vim.notify("API Error", vim.log.levels.ERROR)
				return
			end

			local res = table.concat(job:result(), "")
			local decoded = vim.fn.json_decode(res)
			local content_str = decoded.choices[1].message.content
			local tags_data = vim.fn.json_decode(content_str)

			local final_tags = {}
			for _, t in ipairs(tags_data.subjectTags or {}) do
				table.insert(final_tags, t)
			end
			for _, t in ipairs(tags_data.intentTags or {}) do
				table.insert(final_tags, t)
			end

			local new_fm, insert_pos = remove_tags_and_get_pos(fm_lines)
			table.insert(new_fm, insert_pos, "tags:")
			for i, tag in ipairs(final_tags) do
				table.insert(new_fm, insert_pos + i, "  - " .. tag)
			end

			local final_block = { "---" }
			for _, l in ipairs(new_fm) do
				table.insert(final_block, l)
			end
			table.insert(final_block, "---")

			vim.api.nvim_buf_set_lines(bufnr, 0, fm_end or 0, false, final_block)
			vim.notify("Tags applied!", vim.log.levels.INFO)
		end),
	}):start()
end

-- ===================================================================
-- LIST FORMATTING HELPERS
-- ===================================================================

local function get_paragraph_range()
	local current_line = vim.fn.line(".")
	local start_line = current_line
	local end_line = current_line
	local total_lines = vim.fn.line("$")

	-- Find start (go up until empty line)
	while start_line > 1 do
		local line_content = vim.fn.getline(start_line - 1)
		if line_content:match("^%s*$") then
			break
		end
		start_line = start_line - 1
	end

	-- Find end (go down until empty line)
	while end_line < total_lines do
		local line_content = vim.fn.getline(end_line + 1)
		if line_content:match("^%s*$") then
			break
		end
		end_line = end_line + 1
	end
	return start_line, end_line
end

local function format_range_as_list(start_line, end_line)
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local char_code = string.byte("A")

	for i, line_content in ipairs(lines) do
		if not line_content:match("^%s*$") then
			local prefix = string.char(char_code) .. ". "
			lines[i] = prefix .. line_content
			char_code = char_code + 1
		end
	end

	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
	vim.api.nvim_win_set_cursor(0, { end_line, 0 })
end

-- EXPORTED FUNCTIONS FOR KEYMAPS
function M.create_list_visual()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	format_range_as_list(start_line, end_line)
end

function M.create_list_paragraph()
	local start_line, end_line = get_paragraph_range()
	format_range_as_list(start_line, end_line)
end

return M
````

## `llm_keymaps.lua`

---

```lua
-- ===========================================================================
-- llm.nvim Plugin Keymap Configuration
-- ===========================================================================
-- ~/.config/nvim/lua/dusts/core/llm_keymaps.lua
local M = {}
-- Helper function moved here as it is used by keybinds
local function get_comment_syntax()
	local ft = vim.bo.filetype
	local comment_markers = {
		lua = "--",
		python = "#",
		cisco = "!",
		javascript = "//",
		typescript = "//",
		java = "//",
		cpp = "//",
		c = "//",
		rust = "//",
		go = "//",
	}
	return comment_markers[ft] or "#"
end

function M.setup(llm, prompts)
	-- Claude Sonnet 4.5
	vim.keymap.set("v", "<leader>na", function()
		llm.prompt_selection_only_append({
			service = "anthropic",
			system_prompt = prompts.note_system_prompt,
		})
	end, { desc = "Claude Opus = $5.00/$25.00" })

	-- GPT-5
	vim.keymap.set("v", "<leader>nt", function()
		llm.prompt_selection_only_append({
			service = "gpt_5",
			system_prompt = prompts.note_system_prompt,
			-- temperature = 0.75,
			verbosity = "low",
			reasoning_effort = "high",
		})
	end, { desc = "GPT-5.4 = $2.50/$15.00" })

	-- Grok
	vim.keymap.set("v", "<leader>nk", function()
		llm.prompt_selection_only_append({
			service = "grok",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Grok 4.3 = $0.25/$2.50" })

	-- OpenRouter
	vim.keymap.set("v", "<leader>no", function()
		llm.prompt_selection_only_append({
			service = "openrouter",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Stealth OWL" })

	-- Gemini Flash
	vim.keymap.set("v", "<leader>ngf", function()
		llm.prompt_selection_only_append({
			service = "flash",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Gemini 3.1 Flash $0.50/$3.00" })

	-- Gemini Flash
	vim.keymap.set("v", "<leader>ngl", function()
		llm.prompt_selection_only_append({
			service = "flash_lite",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
		-- end, { desc = "Gemini 2.5 Flash-Lite $0.10/$0.40" })
	end, { desc = "Gemini 3.1 Flash-Lite $0.25/$1.50" })

	-- Qwen
	vim.keymap.set("v", "<leader>nw", function()
		llm.prompt_selection_only_append({
			service = "qwen3",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Qwen3.5 Flash $0.10/$0.40" })

	-- Gemini Pro
	vim.keymap.set("v", "<leader>ngm", function()
		llm.prompt_selection_only_append({
			service = "gemini",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Gemini 3.1 Pro $2.00/$12.00" })

	-- GPT-5 Nano
	vim.keymap.set("v", "<leader>ngp", function()
		llm.prompt_selection_only_append({
			service = "openai",
			system_prompt = prompts.note_system_prompt,
			-- temperature = 0.75,
			verbosity = "low",
			reasoning_effort = "medium",
		})
	end, { desc = "GPT-5 Nano $0.05/$0.40" })

	-- Gemma
	vim.keymap.set("v", "<leader>ne", function()
		llm.prompt_selection_only_append({
			service = "gemma",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Gemma 27B" })

	-- Deepseek
	vim.keymap.set("v", "<leader>nd", function()
		llm.prompt_selection_only_append({
			service = "deepseek",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
		-- end, { desc = "Deepseek V4 Flash $0.14/$0.28" })
	end, { desc = "Deepseek V4 Pro $1.74/$3.48" })

	-- Tiny Llama
	vim.keymap.set("v", "<leader>tlm", function()
		llm.prompt_selection_only_append({
			service = "tiny_llama",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Llama 3.2 8B $0.02/$0.05" })

	-- Tiny Qwen
	vim.keymap.set("v", "<leader>tqw", function()
		llm.prompt_selection_only_append({
			service = "tiny_qwen3",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
			reasoning_effort = "none",
			-- temperature = 0.4, -- Lower temp stops it from getting distracted
			-- reasoning_tokens = 1024, -- Force it to stop thinking after ~1000 tokens
		})
	end, { desc = "Qwen3.5 9B $0.05/$0.15" })

	-- Kimi
	vim.keymap.set("v", "<leader>tkk", function()
		llm.prompt_selection_only_append({
			service = "kimi_k2",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Kimi K2.5 $0.45/$2.20" })

	-- Ministral
	vim.keymap.set("v", "<leader>tmo", function()
		llm.prompt_selection_only_append({
			service = "molmo",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Molmo2 8B Free" })

	-- Ministral
	vim.keymap.set("v", "<leader>tmi", function()
		llm.prompt_selection_only_append({
			service = "ministral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Ministral 14B" })

	-- Nemostral
	vim.keymap.set("v", "<leader>tnm", function()
		llm.prompt_selection_only_append({
			service = "nemostral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Mistral Nemo" })

	-- Trinity Large
	vim.keymap.set("v", "<leader>tnt", function()
		llm.prompt_selection_only_append({
			service = "trinity_large",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Trinity Large Free" })

	-- Devstral
	vim.keymap.set("v", "<leader>tdv", function()
		llm.prompt_selection_only_append({
			service = "devstral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Devstral Small 24B" })

	-- Codestral
	vim.keymap.set("v", "<leader>tcd", function()
		llm.prompt_selection_only_append({
			service = "codestral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Codestral 22B" })

	-- R1T2
	vim.keymap.set("v", "<leader>trt", function()
		llm.prompt_selection_only_append({
			service = "r1_t2",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "R1T2 Chimera" })

	-- Olmo
	vim.keymap.set("v", "<leader>nmo", function()
		llm.prompt_selection_only_append({
			service = "olmo",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Olmo 3.1 32B Instruct" })

	-- Nemotron Nano
	vim.keymap.set("v", "<leader>nmn", function()
		llm.prompt_selection_only_append({
			service = "nemotron",
			reasoning = "true",
			temperature = 0,
		})
	end, { desc = "Nemotron 3 Super Free" })

	-- Mimo V2 Flash
	vim.keymap.set("v", "<leader>nmi", function()
		llm.prompt_selection_only_append({
			service = "mimo",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Mimo - $0.09/$0.29" })

	-- Minimax
	vim.keymap.set("v", "<leader>nmx", function()
		llm.prompt_selection_only_append({
			service = "minimax",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Minimax 2.7 - $0.30/$1.20" })

	-- Mistral
	vim.keymap.set("v", "<leader>nms", function()
		llm.prompt_selection_only_append({
			service = "mistral",
			reasoning = "true",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Mistral 4 Small" })

	-- Nemotron
	vim.keymap.set("v", "<leader>nu", function()
		llm.prompt_selection_only_append({
			service = "nemotron_ultra",
			thinking = "off",
			system_prompt = prompts.note_system_prompt,
			temperature = 0,
		})
	end, { desc = "Nemotron Ultra 235B" })

	vim.keymap.set("v", "<leader>nc", function()
		llm.prompt_selection_only_append({
			service = "cerebras",
			system_prompt = prompts.note_system_prompt,
			-- reasoning_effort = "high",
			max_tokens = 32768,
			temperature = 0.75,
		})
	end, { desc = "Cerebras gpt-oss-120b" })

	-- Groq Qwen
	vim.keymap.set("v", "<leader>nq", function()
		llm.prompt_selection_only_append({
			service = "groq",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Groq (Qwen3-32B)" })

	-- Z AI
	vim.keymap.set("v", "<leader>nz", function()
		llm.prompt_selection_only_append({
			service = "z_ai",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Z AI (GLM 4.7 $0.60/$2.80)" })

	-- Replace with Mistral
	vim.keymap.set("v", "<leader>nr", function()
		llm.prompt_selection_only({
			replace = true,
			service = "mistral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.5,
		})
	end, { desc = "Replace selection with Mistral Medium" })

	-- Code Append
	vim.keymap.set("v", "<leader>ct", function()
		llm.prompt_selection_only_append({
			service = "codestral",
			system_prompt = prompts.code_system_prompt,
			temperature = 0.1,
			comment_syntax = get_comment_syntax(),
		})
	end, { desc = "Codestral" })

	-- Code Replace
	vim.keymap.set("v", "<leader>cr", function()
		llm.prompt_selection_only({
			replace = true,
			service = "codestral",
			system_prompt = prompts.code_system_prompt,
			temperature = 0.1,
			comment_syntax = get_comment_syntax(),
		})
	end, { desc = "Replace with Codestral" })

	-- Title/Spiel
	vim.keymap.set("v", "<leader>mt", function()
		llm.prompt_selection_only_append({
			service = "flash_lite",
			system_prompt = prompts.title_spiel_prompt,
			temperature = 0.6,
			-- verbosity = "low", -- For GPT-5
			-- reasoning_effort = "high", -- For GPT-5
			is_document_prompt = true,
		})
	end, { desc = "Provide a title, subtitle, and spiel" })

	-- YouTube Clean
	vim.keymap.set("v", "<leader>myc", function()
		llm.prompt_selection_only_append({
			service = "grok",
			system_prompt = prompts.youtube_transcript_cleaner_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Generate a clean version of youtube video transcript" })

	-- YouTube Summary
	vim.keymap.set("v", "<leader>mys", function()
		llm.prompt_selection_only_append({
			service = "r1",
			system_prompt = prompts.youtube_clean_transcript_summary_generator_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Make a summary from Clean YouTube transcript" })

	-- Clean Scraped (Flash)
	vim.keymap.set("v", "<leader>msf", function()
		llm.prompt_selection_only({
			replace = true,
			service = "flash_lite",
			system_prompt = prompts.clean_scraped_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean Scraped Markdown Content w/ Gemini Flash Lite" })

	-- Clean Scraped (Grok)
	vim.keymap.set("v", "<leader>msg", function()
		llm.prompt_selection_only({
			replace = true,
			service = "grok",
			system_prompt = prompts.clean_scraped_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean Scraped Markdown Content w/ Grok 4" })

	-- Clean Scraped (OpenAI)
	vim.keymap.set("v", "<leader>mso", function()
		llm.prompt_selection_only({
			replace = true,
			service = "openai",
			system_prompt = prompts.clean_scraped_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean Scraped Markdown Content w/ GPT 5 Mini" })

	-- Clean Output (Grok)
	vim.keymap.set("v", "<leader>mck", function()
		llm.prompt_selection_only({
			replace = true,
			service = "grok",
			system_prompt = prompts.clean_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean LLM Output Markdown for Readability w/ Grok 4" })

	-- Clean Output (OpenAI)
	vim.keymap.set("v", "<leader>mco", function()
		llm.prompt_selection_only({
			replace = true,
			service = "openai",
			system_prompt = prompts.clean_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean LLM Output Markdown for Readability w/ GPT 5 Mini" })

	-- Clean Output (Grok - duplicate keybind in original, kept intentionally)
	vim.keymap.set("v", "<leader>mcg", function()
		llm.prompt_selection_only({
			replace = true,
			service = "grok",
			system_prompt = prompts.clean_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean LLM Output Markdown for Readability w/ Grok 4" })

	-- Clean Output (Flash)
	vim.keymap.set("v", "<leader>mcf", function()
		llm.prompt_selection_only({
			replace = true,
			service = "flash_lite",
			system_prompt = prompts.clean_markdown_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Clean LLM Output Markdown for Readability w/ Gemini Flash Lite" })

	-- Course Generator
	vim.keymap.set("v", "<leader>mcc", function()
		llm.prompt_selection_only({
			replace = true,
			service = "flash_lite",
			system_prompt = prompts.course_generator_prompt,
			temperature = 0.6,
			is_document_prompt = true,
		})
	end, { desc = "Convert Video Transcript to Textbook Course (Readable Content)" })

	-- Bullet Points
	vim.keymap.set("v", "<leader>mgb", function()
		llm.prompt_selection_only_append({
			service = "ministral",
			system_prompt = prompts.note_system_prompt .. [[
                Can you split the following text into a markdown bullet list
            ]],
			temperature = 0.5,
			is_document_prompt = true,
		})
	end, { desc = "Generate bullet points from Paragraph" })

	-- Subtitle
	vim.keymap.set("v", "<leader>mgs", function()
		llm.prompt_selection_only_append({
			service = "flash_lite",
			system_prompt = prompts.note_system_prompt .. [[
                Please provide a easy and quick to read
                subtitle (as if glancing through a large amount of
                paragraphs) that captures the main idea and
                is eye catching for the only following paragraph

                Only provide the subtitle and not the paragraph
                Don't regenerate the paragraph
            ]],
			temperature = 0.1,
			is_document_prompt = true,
		})
	end, { desc = "Generate a subtitle for Paragraph" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mei", function()
		llm.prompt_selection_only_append({
			service = "mimo",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter!" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mem", function()
		llm.prompt_selection_only_append({
			service = "minimax",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Minimax!" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mek", function()
		llm.prompt_selection_only_append({
			service = "grok",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Grok!" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>meg", function()
		llm.prompt_selection_only_append({
			service = "gpt_5",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter GPT-5!" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mec", function()
		llm.prompt_selection_only_append({
			service = "cerebras",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Cerebras (OSS-120B)" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>meq", function()
		llm.prompt_selection_only_append({
			service = "qwen3",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Qwen3 A3B 30B" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>meo", function()
		llm.prompt_selection_only_append({
			service = "openrouter",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter OpenRouter" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mer", function()
		llm.prompt_selection_only_append({
			service = "mistral",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Mistral" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>met", function()
		llm.prompt_selection_only_append({
			service = "tiny_llama",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Tiny Llama" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>mef", function()
		llm.prompt_selection_only_append({
			service = "flash_lite",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Gemini Flash Lite" })

	-- Explain It To me
	vim.keymap.set("v", "<leader>med", function()
		llm.prompt_selection_only_append({
			service = "deepseek",
			system_prompt = prompts.lets_rock_peter,
			temperature = 0.50,
			is_document_prompt = true,
		})
	end, { desc = "Explain It Peter Deepseek" })

	-- Clean Bad YAML
	vim.keymap.set("v", "<leader>cby", function()
		llm.prompt_selection_only({
			replace = true,
			service = "cerebras",
			system_prompt = prompts.clean_bad_yaml,
			temperature = 0.20,
			is_document_prompt = true,
			reasoning_format = "hidden",
		})
	end, { desc = "Clean Bad YAML" })
end

return M
```
