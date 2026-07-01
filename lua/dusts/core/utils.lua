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

function M.insert_date()
	--2026-05-19 @ 3:26:40PM
	local date = os.date("%Y-%m-%d @%l:%M:%S%p")
	vim.api.nvim_put({ date }, "c", true, true)
end

return M
