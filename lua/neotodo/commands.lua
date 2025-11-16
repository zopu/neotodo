-- commands.lua - Command implementations for NeoTODO

local parser = require("neotodo.parser")
local config = require("neotodo.config")

local M = {}

--- Add a new task to the "New" section
--- Creates the "New:" section at the top if it doesn't exist
--- Adds an indented line and enters insert mode
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.add_task(bufnr)
	bufnr = bufnr or 0
	local sections = parser.get_sections(bufnr)

	-- Find the "New" section
	local new_section = nil
	for _, section in ipairs(sections) do
		if section.name == "New" then
			new_section = section
			break
		end
	end

	local task_indent = string.rep(" ", config.options.task_indent)
	local new_task_line = task_indent

	if new_section then
		-- "New" section exists, add task after the header
		local start_line, end_line = parser.get_section_range("New", bufnr)

		-- Find the last task line in the New section
		local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
		local insert_pos = start_line -- Position after the header

		-- Find the last non-empty task line
		for i = 2, #lines do
			if parser.is_task_line(lines[i]) then
				insert_pos = start_line + i - 1
			end
		end

		-- Insert the new task line
		vim.api.nvim_buf_set_lines(bufnr, insert_pos, insert_pos, false, { new_task_line })

		-- Move cursor to the new line and enter insert mode
		local cursor_line = insert_pos + 1
		vim.api.nvim_win_set_cursor(0, { cursor_line, #task_indent })
		vim.cmd("startinsert!")
	else
		-- "New" section doesn't exist, create it at the top
		local new_section_lines = {
			"New:",
			new_task_line,
		}

		-- Check if buffer has actual content
		local existing_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local has_content = false
		for _, line in ipairs(existing_lines) do
			if line ~= "" then
				has_content = true
				break
			end
		end

		-- Add a blank line after if there's content in the buffer
		if has_content then
			table.insert(new_section_lines, "")
		end

		-- Insert at the beginning of the buffer
		-- If buffer is empty (just one blank line), replace it; otherwise insert
		if #existing_lines == 1 and existing_lines[1] == "" then
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, new_section_lines)
		else
			vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, new_section_lines)
		end

		-- Move cursor to the new task line (line 2) and enter insert mode
		vim.api.nvim_win_set_cursor(0, { 2, #task_indent })
		vim.cmd("startinsert!")
	end
end

return M
