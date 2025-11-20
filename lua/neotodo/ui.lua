-- ui.lua - UI helpers for NeoTODO (section picker, navigation)

local parser = require("neotodo.parser")

local M = {}

--- Get preview content for a section (the tasks within it)
--- @param section_name string The section name
--- @param bufnr number Buffer number
--- @return string Preview text
local function get_section_preview(section_name, bufnr)
	local start_line, end_line = parser.get_section_range(section_name, bufnr)
	if not start_line or not end_line then
		return "Empty section"
	end

	-- Get all lines in the section
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	-- Filter to only show tasks (indented lines) and skip the header
	local preview_lines = {}
	for i = 2, #lines do -- Start from 2 to skip section header
		local line = lines[i]
		if parser.is_task_line(line) then
			table.insert(preview_lines, line)
		end
	end

	if #preview_lines == 0 then
		return "No tasks in this section"
	end

	return table.concat(preview_lines, "\n")
end

--- Format sections for display in the picker
--- @param sections table Array of {name = string, line = number}
--- @param bufnr number Buffer number for preview content
--- @return table Array of formatted items for the picker
function M.format_sections_for_picker(sections, bufnr)
	bufnr = bufnr or 0
	local items = {}
	local max_name_length = 0

	-- Calculate max name length for alignment
	for _, section in ipairs(sections) do
		max_name_length = math.max(max_name_length, #section.name)
	end

	local padding = max_name_length + 2

	for _, section in ipairs(sections) do
		table.insert(items, {
			-- text field is used for searching
			text = section.name .. " line " .. section.line,
			name = section.name,
			line = section.line,
			padding = padding,
			-- Add preview content showing the tasks in this section
			preview = {
				text = get_section_preview(section.name, bufnr),
			},
		})
	end
	return items
end

--- Show a section picker using Snacks.picker
--- @param sections table Array of {name = string, line = number}
--- @param callback function(section_name: string, line: number) Callback when section is selected
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @param prompt string|nil Custom prompt text (defaults to "Select Section")
function M.pick_section(sections, callback, bufnr, prompt)
	bufnr = bufnr or 0
	prompt = prompt or "Select Section"

	if #sections == 0 then
		vim.notify("No sections found in TODO file", vim.log.levels.WARN)
		return
	end

	-- Check if Snacks is available
	local snacks_ok, snacks = pcall(require, "snacks")
	if not snacks_ok or not snacks.picker then
		vim.notify("Snacks.picker is not available. Please install folke/snacks.nvim", vim.log.levels.ERROR)
		return
	end

	-- Format sections for display with preview content
	local items = M.format_sections_for_picker(sections, bufnr)

	-- Create picker configuration
	snacks.picker({
		items = items,
		format = function(item)
			local ret = {}
			-- Section name with primary highlight
			ret[#ret + 1] = { item.name, "SnacksPickerLabel" }
			-- Padding for alignment
			ret[#ret + 1] = { string.rep(" ", item.padding - #item.name), virtual = true }
			-- Line number with secondary highlight
			ret[#ret + 1] = { "(line " .. item.line .. ")", "SnacksPickerComment" }
			return ret
		end,
		confirm = function(picker, item)
			picker:close()
			if item and callback then
				callback(item.name, item.line)
			end
		end,
		prompt = prompt .. ": ",
		preview = "preview", -- Enable preview showing section content
	})
end

--- Navigate to a section by moving the cursor to its header line
--- @param section_name string The name of the section to navigate to
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.navigate_to_section_direct(section_name, bufnr)
	bufnr = bufnr or 0
	local sections = parser.get_sections(bufnr)

	-- Find the section
	for _, section in ipairs(sections) do
		if section.name == section_name then
			-- Move cursor to the section header line
			vim.api.nvim_win_set_cursor(0, { section.line, 0 })
			return
		end
	end

	vim.notify("Section '" .. section_name .. "' not found", vim.log.levels.WARN)
end

return M
