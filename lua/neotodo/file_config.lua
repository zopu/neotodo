local M = {}

-- Cache for loaded file configs (key: directory path, value: config table or false)
M._cache = {}

--- Find .todo.json config file starting from dir and searching parent directories
---@param dir string Starting directory path
---@return string|nil Path to .todo.json if found, nil otherwise
local function find_config_file(dir)
	local config_name = ".todo.json"
	local current = dir

	while current and current ~= "" do
		local config_path = current .. "/" .. config_name
		local stat = vim.loop.fs_stat(config_path)
		if stat and stat.type == "file" then
			return config_path
		end

		-- Move to parent directory
		local parent = vim.fn.fnamemodify(current, ":h")
		if parent == current then
			break -- Reached root
		end
		current = parent
	end

	return nil
end

--- Load and parse a .todo.json file
---@param config_path string Path to the config file
---@return table|nil Parsed config table, or nil on error
local function load_config_file(config_path)
	local file = io.open(config_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	if not content or content == "" then
		return {}
	end

	local ok, result = pcall(vim.json.decode, content)
	if not ok then
		vim.notify("Failed to parse " .. config_path .. ": " .. tostring(result), vim.log.levels.WARN)
		return nil
	end

	return result
end

--- Get the file-specific config for a buffer
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return table Config table (may be empty if no .todo.json found)
function M.get_config(bufnr)
	bufnr = bufnr or 0
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local dir = vim.fn.fnamemodify(bufname, ":p:h")

	-- Check cache first
	if M._cache[dir] ~= nil then
		return M._cache[dir] or {}
	end

	-- Find and load config
	local config_path = find_config_file(dir)
	if not config_path then
		M._cache[dir] = false
		return {}
	end

	local config = load_config_file(config_path)
	M._cache[dir] = config or false
	return config or {}
end

--- Get the import command from file config
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string|nil Shell command for importing tasks, or nil if not configured
function M.get_import_command(bufnr)
	local config = M.get_config(bufnr)
	return config.import_command
end

--- Clear the config cache (useful for testing or when config files change)
function M.clear_cache()
	M._cache = {}
end

return M
