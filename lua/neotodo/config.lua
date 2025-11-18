local M = {}

-- Default configuration options
M.defaults = {
	-- Keybindings (nil means no default keybind)
	keybinds = {
		add_task = nil, -- Add new task to "New" section
		mark_done = nil, -- Mark task as done
		move_to_now = nil, -- Move task to "Now" section
		move_to_section = nil, -- Navigate to section (with picker)
		move_task = nil, -- Move task to section (with picker)
		focus_enable = nil, -- Enable focus mode
		focus_disable = nil, -- Disable focus mode
		focus_toggle = nil, -- Toggle focus mode
	},

	-- File detection pattern
	file_pattern = "TODO.txt",

	-- Indentation for tasks (number of spaces)
	task_indent = 2,

	-- Sections that remain visible in focus mode
	focus_sections = { "Now", "Today", "Top This Week" },
}

-- Current configuration (starts as defaults)
M.options = vim.deepcopy(M.defaults)

-- Merge user config with defaults
function M.setup(user_config)
	user_config = user_config or {}
	M.options = vim.tbl_deep_extend("force", M.defaults, user_config)
	return M.options
end

return M
