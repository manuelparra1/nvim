-- ===========================================================================
-- llm.nvim Plugin Keymap Configuration
-- ===========================================================================
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
	-- Claude Opus 4.8
	vim.keymap.set("v", "<leader>na", function()
		llm.prompt_selection_only_append({
			-- service = "anthropic",
			service = "opus",
			system_prompt = prompts.note_system_prompt,
		})
	end, { desc = "Claude Opus 4.8 = $5.00/$25.00" })

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
			-- system_prompt = prompts.note_system_prompt,
			system_prompt = prompts.better_concise_2,
			temperature = 0.75,
			thinking = "off",
		})
		-- end, { desc = "Mimo v2.5 = $0.14/$0.28" })
	end, { desc = "Deepseek v4 Flash = $0.09/$0.18" })
	-- end, { desc = "GLM 5.2 $1.40/$4.40" })

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
	end, { desc = "Gemini 3.1 Flash-Lite $0.25/$1.50" })

	-- Qwen
	vim.keymap.set("v", "<leader>nw", function()
		llm.prompt_selection_only_append({
			service = "qwen3",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Qwen3.7 Max $1.25/$3.75" })

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
	end, { desc = "Gemma 4 31B" })

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

	-- Codestral
	vim.keymap.set("v", "<leader>tcd", function()
		llm.prompt_selection_only_append({
			service = "codestral",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.75,
		})
	end, { desc = "Codestral 22B" })

	-- Mimo V2.5
	vim.keymap.set("v", "<leader>nmi", function()
		llm.prompt_selection_only_append({
			service = "mimo",
			-- system_prompt = prompts.note_system_prompt,
			-- system_prompt = prompts.better_concise,
			system_prompt = prompts.better_concise_2,
			temperature = 0.75,
			thinking = "off",
		})
	end, { desc = "Mimo V2.5 Pro - $0.435/$0.87" })

	-- Minimax
	vim.keymap.set("v", "<leader>nmx", function()
		llm.prompt_selection_only_append({
			service = "minimax",
			-- system_prompt = prompts.note_system_prompt,
			system_prompt = prompts.better_concise_2,
			temperature = 0.75,
			thinking = "off",
		})
		-- end, { desc = "Minimax 2.7 - $0.30/$1.20" })
	end, { desc = "Minimax 3 - $0.30/$1.20" })

	vim.keymap.set("v", "<leader>nc", function()
		llm.prompt_selection_only_append({
			service = "cerebras",
			-- system_prompt = prompts.note_system_prompt,
			-- system_prompt = prompts.better_concise,
			system_prompt = prompts.better_concise_2,
			-- reasoning_effort = "high",
			max_tokens = 32768,
			temperature = 0.75,
			reasoning_format = "hidden",
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
	end, { desc = "Z AI (GLM 5.2 $1.40/$4.40)" })

	-- Replace with Mistral
	vim.keymap.set("v", "<leader>nr", function()
		llm.prompt_selection_only({
			replace = true,
			service = "cerebras",
			system_prompt = prompts.note_system_prompt,
			temperature = 0.5,
		})
	end, { desc = "Replace selection with Cerebras" })

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
			-- service = "flash_lite",
			service = "openrouter",
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
			max_tokens = 2048,
			is_document_prompt = true,
			reasoning_format = "hidden",
		})
	end, { desc = "Clean Bad YAML" })

	-- Reword Like a Junior Engineer
	vim.keymap.set("v", "<leader>mrj", function()
		llm.prompt_selection_only({
			replace = true,
			service = "cerebras",
			system_prompt = prompts.editor_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 4096,
			is_document_prompt = true,
			reasoning_format = "hidden",
		})
	end, { desc = "Reword Like a Junior Engineer" })

	-- Reword Like a Junior Engineer & Clean Structure
	vim.keymap.set("v", "<leader>mrf", function()
		llm.prompt_selection_only({
			replace = true,
			service = "cerebras",
			system_prompt = prompts.cleaner_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 4096,
			is_document_prompt = true,
			reasoning_format = "hidden",
		})
	end, { desc = "Reword Like a Junior Engineer & Simplify Structure" })

	-- Chat with reworded responses Like a Junior Engineer & Clean Structure
	vim.keymap.set("v", "<leader>njm", function()
		llm.prompt_selection_only({
			service = "mimo",
			system_prompt = prompts.cleaner_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "Mimo V2.5 Pro: Chat with Junior Engineer & Simplify Structure" })

	-- Chat with reworded responses Like a Junior Engineer & Clean Structure
	vim.keymap.set("v", "<leader>njz", function()
		llm.prompt_selection_only({
			service = "z_ai",
			system_prompt = prompts.cleaner_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "GLM 5.2: Chat with Junior Engineer & Simplify Structure" })

	-- Chat with a Junior Engineer & Clean Structure
	vim.keymap.set("v", "<leader>njc", function()
		llm.prompt_selection_only({
			service = "cerebras",
			-- system_prompt = prompts.cleaner_base .. "\n\n" .. prompts.junior_engineer_prompt,
			system_prompt = prompts.cleaner_base
				.. "\n\n# COMMUNICATION STYLE GUIDELINES\n\n"
				.. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8192,
			reasoning_format = "hidden",
		})
	end, { desc = "OSS-120B: Chat with Junior Engineer & Clean Structure" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ncc", function()
		llm.prompt_selection_only({
			service = "cerebras",
			system_prompt = prompts.editor_base
				.. "\n\n# COMMUNICATION STYLE GUIDELINES\n\n"
				.. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "OSS-120B: Chat with Junior Engineer" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ajc", function()
		llm.prompt_selection_only({
			service = "cerebras",
			system_prompt = prompts.annotated_notes
				.. "\n\n# COMMUNICATION STYLE GUIDELINES\n\n"
				.. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "OSS-120B: Junior Engineer Annotated Notes" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ajm", function()
		llm.prompt_selection_only({
			service = "mimo",
			--system_prompt = prompts.editor_base .. "\n\n" .. prompts.junior_engineer_prompt,
			system_prompt = prompts.editor_base
				.. "\n\n# COMMUNICATION STYLE GUIDELINES\n\n"
				.. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8192,
			reasoning_format = "hidden",
		})
	end, { desc = "Mimo V2.5 Pro: Chat with Junior Engineer" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ajx", function()
		llm.prompt_selection_only({
			service = "minimax",
			system_prompt = prompts.editor_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "Minimax 3: Chat with Junior Engineer" })

	-- Chat like a Junior Engineer
	vim.keymap.set("v", "<leader>ajg", function()
		llm.prompt_selection_only({
			service = "gpt_5",
			system_prompt = prompts.annotated_notes
				.. "\n\n# COMMUNICATION STYLE GUIDELINES\n\n"
				.. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8192,
			reasoning_format = "hidden",
		})
	end, { desc = "Chat with Junior Engineer" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ajd", function()
		llm.prompt_selection_only({
			service = "openrouter",
			system_prompt = prompts.editor_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "Deepseek V4 Flash: Chat with Junior Engineer" })

	-- Chat with like a Junior Engineer
	vim.keymap.set("v", "<leader>ajz", function()
		llm.prompt_selection_only({
			service = "z_ai",
			system_prompt = prompts.editor_base .. "\n\n" .. prompts.junior_engineer_prompt,
			temperature = 0.20,
			max_tokens = 8092,
			reasoning_format = "hidden",
		})
	end, { desc = "GLM 5.2: Chat with Junior Engineer" })
end

return M
