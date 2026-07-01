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

				if state.placeholder_line ~= nil then
					vim.api.nvim_buf_set_lines(0, state.placeholder_line, state.placeholder_line + 1, false, { "" })
					state.line = state.placeholder_line
				else
					vim.api.nvim_buf_set_lines(0, math.max(state.line - 1, 0), state.line, false, {})
					state.line = math.max(state.line - 1, 0)
				end
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
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

			vim.defer_fn(function()
				local start_row = math.min(vim.fn.line("'<"), vim.fn.line("'>"))
				local end_row = math.max(vim.fn.line("'<"), vim.fn.line("'>"))

				vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, { "Thinking..." })

				sse_state.line = start_row - 1
				sse_state.placeholder_line = start_row - 1
				vim.api.nvim_win_set_cursor(0, { start_row, 0 })
			end, 20)
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

			if service == "cerebras" then
				if opts.reasoning_format then
					data.reasoning_format = opts.reasoning_format
				end

				if opts.reasoning_effort then
					data.reasoning_effort = opts.reasoning_effort
				end
			elseif opts.reasoning == "true" or opts.reasoning_effort then
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
