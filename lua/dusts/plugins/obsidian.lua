return {
	"obsidian-nvim/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",

	dependencies = {
		"nvim-lua/plenary.nvim",
	},

	opts = {
		legacy_commands = false,

		ui = {
			enable = false,
		},

		workspaces = {
			{
				name = "Personal",
				path = "/Users/dusts/aston/Notes/Obsidian/aston",
			},
			{
				name = "Work",
				path = "/Users/dusts/aston/Notes/Obsidian/Network-Engineer",
			},
		},

		notes_subdir = "Inbox",
		new_notes_location = "notes_subdir",

		frontmatter = {
			enabled = true,

			func = function(note)
				local frontmatter = {}

				-- Preserve existing/manual YAML metadata first.
				if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
					for key, value in pairs(note.metadata) do
						frontmatter[key] = value
					end
				end

				-- Core obsidian.nvim fields.
				if note.id then
					frontmatter.id = note.id
				end

				if note.aliases then
					frontmatter.aliases = note.aliases
				end

				if note.tags then
					frontmatter.tags = note.tags
				end

				-- Prefer plugin note title if available.
				-- Otherwise use the first Markdown H1 heading: "# Heading"
				if note.title then
					frontmatter.title = note.title
				else
					local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

					for _, line in ipairs(lines) do
						local heading = line:match("^#%s+(.+)$")
						if heading then
							frontmatter.title = heading
							break
						end
					end
				end

				-- Keep created stable once it exists.
				if not frontmatter.created then
					frontmatter.created = os.date("%Y-%m-%dT%H:%M:%S", os.time())
				end

				-- Always update modified.
				frontmatter.modified = os.date("%Y-%m-%dT%H:%M:%S", os.time())

				return frontmatter
			end,
		},
	},
}
