-- ===========================================================================
-- llm.nvim Plugin LLM Service Configuration
-- ===========================================================================
return {
	fugu = {
		-- url = "https://api.sakana.ai/v1/chat/completions",
		url = "https://api.sakana.ai/v1/responses",
		model = "fugu-ultra",
		api_key_name = "SAKANA_API_KEY",
	},
	openrouter = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		--
		-- cost = 0.09/0.18 @ (40 AA Score)
		model = "deepseek/deepseek-v4-flash",
		--
		-- cost = 0.14/0.28 @ (40 AA Score)
		-- model = "xiaomi/mimo-v2.5",
		--
		-- cost = 1.00/4.00 @ (51 AA Score)
		-- model = "z-ai/glm-5.2",
		api_key_name = "OPENROUTER_API_KEY",
	},
	opus = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "anthropic/claude-opus-4.8",
		stream = true,
		api_key_name = "OPENROUTER_API_KEY",
	},
	gpt_5 = {
		url = "https://api.openai.com/v1/responses", -- FIXED: was /v1/chat/completions
		model = "gpt-5.4",
		-- 2x Price
		-- model = "gpt-5.5",
		api_key_name = "OPENAI_API_KEY",
		api_type = "responses", -- NEW
	},
	z_ai = {
		url = "https://api.z.ai/api/paas/v4/chat/completions",
		model = "glm-5.2",
		api_key_name = "Z_API_KEY",
	},
	minimax = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		-- model = "minimax/minimax-m2.7",
		model = "minimax/minimax-m3",
		api_key_name = "OPENROUTER_API_KEY",
	},
	mimo = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		-- cost = $0.435/$0.87 @ (53.8 AA Score)
		model = "xiaomi/mimo-v2.5-pro",
		api_key_name = "OPENROUTER_API_KEY",
	},
	anthropic = {
		url = "https://api.anthropic.com/v1/messages", -- FIXED: was /v1/chat/completions (doesn't exist)
		model = "claude-opus-4-8",
		api_key_name = "ANTHROPIC_API_KEY",
		api_type = "anthropic", -- NEW
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
		model = "google/gemini-3.1-flash-lite",
		api_key_name = "OPENROUTER_API_KEY",
	},
	flash = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "google/gemini-3-flash-preview",
		api_key_name = "OPENROUTER_API_KEY",
	},
	qwen3 = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "qwen/qwen3.7-max",
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
	nemotron = {
		url = "https://openrouter.ai/api/v1/chat/completions",
		model = "nvidia/nemotron-3-super-120b-a12b:free",
		api_key_name = "OPENROUTER_API_KEY",
	},
	deepseek = {
		url = "https://api.deepseek.com/v1/chat/completions",
		-- cost = $1.74/$3.48 ($0.435/$0.87)
		-- Until 5/31/26 discount
		-- model = "deepseek-v4-pro",
		model = "deepseek-v4-flash",
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
