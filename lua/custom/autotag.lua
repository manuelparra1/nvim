local Job = require("plenary.job")

local M = {}

-- ===================================================================
-- HELPER FUNCTIONS
-- ===================================================================

---
-- Appends a message to the specified log file.
---
--@param log_file string The path to the log file.
--@param message string The message to log.
--
local function log(log_file, message)
	local file = io.open(log_file, "a")
	if file then
		file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
		file:close()
	end
end

---
-- Parses the lines of a buffer to find the YAML frontmatter block.
---
--@param lines table An array of strings representing the lines of the buffer.
--@return integer|nil, integer|nil, table|nil
--
local function find_frontmatter(lines)
	if #lines == 0 or lines[1] ~= "---" then
		return nil, nil, nil
	end
	for i = 2, #lines do
		if lines[i] == "---" then
			local frontmatter_lines = {}
			for j = 2, i - 1 do
				table.insert(frontmatter_lines, lines[j])
			end
			return 1, i, frontmatter_lines
		end
	end
	return nil, nil, nil
end

---
--Robustly removes any existing 'tags' key (single or multi-line) from frontmatter.
--@param fm_lines table The lines of the frontmatter.
--@return table, integer The modified frontmatter lines and the original start index.
--
local function remove_tags_and_get_pos(fm_lines)
	local cleaned_lines = {}
	local insert_pos = #fm_lines + 1 -- Default to the end
	local i = 1
	local tag_key_found = false

	while i <= #fm_lines do
		local line = fm_lines[i]
		if line:match("^tags:") then
			-- Found a tags key. Record its position in the cleaned list and skip it.
			if not tag_key_found then
				insert_pos = #cleaned_lines + 1
				tag_key_found = true
			end

			-- If it's a multi-line block, skip all subsequent list items.
			if line:match("^tags:%s*$") then
				i = i + 1
				while i <= #fm_lines and fm_lines[i]:match("^%s*-") do
					i = i + 1
				end
			else
				-- It's a single-line tags block, just skip this one line.
				i = i + 1
			end
		else
			-- Not a tags line, keep it.
			table.insert(cleaned_lines, line)
			i = i + 1
		end
	end

	return cleaned_lines, insert_pos
end

-- ===================================================================
-- MAIN FUNCTION
-- ===================================================================

function M.generate_and_apply_tags()
	-- ===================================================================
	-- CONFIGURATION
	-- ===================================================================
	local debug_mode = true
	local log_file = "/tmp/autotag_debug.log"

	-- To use OpenRouter:
	local config = {
		api_key_env = "OPENROUTER_API_KEY",
		url = "https://openrouter.ai/api/v1/chat/completions",
		-- payload = { model = "meta-llama/llama-3.2-3b-instruct", temperature = 0.2, max_tokens = 300 },
		payload = { model = "mistralai/mistral-nemo", temperature = 0.1, max_tokens = 128 },
	}
	-- ===================================================================

	if debug_mode then
		local f = io.open(log_file, "w")
		if f then
			f:close()
		end
		log(log_file, "Debug mode enabled. Starting new session.")
	end

	local api_key = os.getenv(config.api_key_env)
	if not api_key then
		vim.notify("API key not set: " .. config.api_key_env, vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local fm_start, fm_end, fm_lines = find_frontmatter(lines)
	fm_lines = fm_lines or {}
	local content_start_idx = (fm_end or 0) + 1
	local content_lines = {}
	for i = content_start_idx, #lines do
		table.insert(content_lines, lines[i])
	end
	local content = table.concat(content_lines, "\n")

	if vim.trim(content) == "" then
		vim.notify("Note content is empty.", vim.log.levels.WARN)
		return
	end

	local prompt_template_2 = [[
    Return only a single JSON object. No prose.

    You must follow these rules:

        Keys: subjectTags, intentTags

        Total tags across both arrays: at most 6

        subjectTags: 1–3 tags, each 1–2 words, Title Case

        intentTags: 2–4 tags, each 2–4 words, lowercase, hyphen-separated

        If unsure, return fewer tags rather than more

        Do not add any keys besides subjectTags and intentTags

    Examples of valid outputs:
    {"subjectTags":["Network Engineering","BGP"],"intentTags":["bgp-path-selection","cisco-interface-configuration"]}
    {"subjectTags":["Python"],"intentTags":["data-cleaning-notes","pandas-cheatsheet"]}

    Now analyze the note content and produce tags. Return only JSON.
    ]]

	local prompt_template =
		[[Analyze the following note content. Your response MUST be a single, valid JSON object and nothing else.

The JSON object should have two keys: "subjectTags" and "intentTags".


These keys will have values that are arrays of strings representing descriptive note tags.

The combined total of tags from "subjectTags" and "intentTags" should be no more than 6. These should be the most relevant tags attributed to the subject of the source content which is the markdown notes.

Maximum number of combined tags in both keys: 6

- "subjectTags": An array of 1-3 single or two-word (in title case) tags identifying the main subject of the markdown notes (e.g.,"Network Engineering", "BGP", "Cisco").

- "intentTags": An array of 2-4 tags describing the markdown notes main purpose, goal, intent, etc, formatted as 2-4 words that are hyphenated, lowercase. The main goal is to look at the entirety of the notes holistically and find their intentended use not just the individual words and what they are similar to. (e.g., "bgp-path-selection", "cisco-interface-configuration", "firewall-configuration-guide, "firewall-best-practices"; if the notes were about network engineering or about firewalls or whatever the subject of the notes are).
]]
	-- local prompt = prompt_template .. "\n\nNote content:" .. content
	local prompt = prompt_template_2 .. "\n\nNote content:" .. content

	vim.notify("Asking LLM to generate descriptive tags...")

	config.payload.response_format = { type = "json_object" }
	config.payload.messages = { { role = "user", content = prompt } }

	local curl_args = {
		"-s",
		config.url,
		"-H",
		"Authorization: Bearer " .. api_key,
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.fn.json_encode(config.payload),
	}
	if debug_mode then
		table.insert(curl_args, 1, "-v")
		log(log_file, "--- Running Command ---\\ncurl " .. table.concat(curl_args, " "))
	end

	Job:new({
		command = "curl",
		args = curl_args,
		on_exit = vim.schedule_wrap(function(job, code)
			local result = job and table.concat(job:result(), "") or "N/A"
			local stderr = job and table.concat(job:stderr_result(), "\n") or "N/A"

			if debug_mode then
				log(log_file, "--- API Response ---")
				log(log_file, "Exit Code: " .. tostring(code))
				log(log_file, "Verbose Output (stderr):\n" .. stderr)
				log(log_file, "Raw Response (stdout):\n" .. result)
			end

			if code ~= 0 or not result or vim.trim(result) == "" then
				vim.notify("API call failed or returned empty. Check log: " .. log_file, vim.log.levels.ERROR)
				return
			end

			local ok, response_data = pcall(vim.fn.json_decode, result)
			if not ok or not response_data then
				vim.notify("Failed to decode API response. Check log: " .. log_file, vim.log.levels.ERROR)
				if debug_mode then
					log(log_file, "JSON Decode Error: " .. tostring(response_data))
				end
				return
			end

			local model_content_str = response_data.choices and response_data.choices[1].message.content
			if not model_content_str then
				vim.notify("API response is missing expected content. Check log.", vim.log.levels.ERROR)
				return
			end

			local content_ok, llm_data = pcall(vim.fn.json_decode, model_content_str)
			if not content_ok or type(llm_data) ~= "table" then
				vim.notify("Failed to decode JSON object from model's content string. Check log.", vim.log.levels.ERROR)
				if debug_mode then
					log(log_file, "Model Content Decode Error: " .. tostring(llm_data))
				end
				return
			end

			local llm_tags = {}
			local subject_tags = llm_data.subjectTags or {}
			local intent_tags = llm_data.intentTags or {}
			for _, tag in ipairs(subject_tags) do
				table.insert(llm_tags, tag)
			end
			for _, tag in ipairs(intent_tags) do
				table.insert(llm_tags, tag)
			end

			if #llm_tags == 0 then
				vim.notify("Model returned no tags. Check log.", vim.log.levels.WARN)
				return
			end

			local insert_pos
			fm_lines, insert_pos = remove_tags_and_get_pos(fm_lines)

			table.insert(fm_lines, insert_pos, "tags:")
			for i, tag in ipairs(llm_tags) do
				table.insert(fm_lines, insert_pos + i, "  - " .. tag)
			end

			local final_fm_block = { "---" }
			for _, line in ipairs(fm_lines) do
				table.insert(final_fm_block, line)
			end
			table.insert(final_fm_block, "---")

			local replace_end_line = fm_end or 0
			vim.api.nvim_buf_set_lines(bufnr, 0, replace_end_line, false, final_fm_block)
			vim.notify("Successfully applied descriptive LLM tags.", vim.log.levels.INFO)
		end),
	}):start()
end

return M
