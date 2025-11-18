-- commands.lua - Command implementations for NeoTODO

local parser = require("neotodo.parser")
local config = require("neotodo.config")
local task_mover = require("neotodo.task_mover")
local focus = require("neotodo.focus")

local M = {}

--- Position cursor intelligently after moving/deleting a task
--- Tries to move to next task, then previous task, then section header
--- @param task_line number The line where the task was before deletion
--- @param section_start number The start line of the section
--- @param section_end number The end line of the section (before deletion)
--- @param bufnr number Buffer number
local function position_cursor_after_task_move(task_line, section_start, section_end, bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- After deletion, the section end is one line earlier
	local adjusted_end = section_end - 1

	-- Search for the next task within the same section
	local next_task_line = nil
	for i = task_line, math.min(adjusted_end, #lines) do
		if parser.is_task_line(lines[i]) then
			next_task_line = i
			break
		end
	end

	if next_task_line then
		-- Found next task in the same section, move cursor there
		vim.api.nvim_win_set_cursor(0, { next_task_line, 0 })
	else
		-- No next task, search backward for previous task in section
		local prev_task_line = nil
		for i = task_line - 1, section_start + 1, -1 do
			if parser.is_task_line(lines[i]) then
				prev_task_line = i
				break
			end
		end

		if prev_task_line then
			-- Found previous task (was second-to-last), move cursor there
			vim.api.nvim_win_set_cursor(0, { prev_task_line, 0 })
		else
			-- No tasks left in section, position at end of section header
			if section_start <= #lines then
				local header_line = lines[section_start]
				vim.api.nvim_win_set_cursor(0, { section_start, #header_line })
			end
		end
	end
end

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

--- Mark the current task as done by moving it to the "Done" section
--- Removes the task from its current section and adds it to "Done:"
--- Creates the "Done:" section if it doesn't exist
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.mark_as_done(bufnr)
	bufnr = bufnr or 0

	-- Get the current task under the cursor
	local task_text, task_line = task_mover.get_current_task(bufnr)

	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- Determine which section the task is in before deletion
	local current_section = parser.get_section_at_line(task_line, bufnr)
	local section_start, section_end = nil, nil

	if current_section then
		section_start, section_end = parser.get_section_range(current_section, bufnr)
	end

	-- Delete the task from its current location
	task_mover.delete_task_line(task_line, bufnr)

	-- Add the task to the "Done" section
	task_mover.add_task_to_section("Done", task_text, bufnr)

	-- Position cursor intelligently in the original section
	if section_start then
		position_cursor_after_task_move(task_line, section_start, section_end, bufnr)
	else
		-- No section found (shouldn't happen), fall back to staying at current position
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local valid_line = math.min(task_line, #lines)
		if valid_line > 0 then
			vim.api.nvim_win_set_cursor(0, { valid_line, 0 })
		end
	end
end

--- Move the current task to the "Now" section
--- Removes the task from its current section and adds it to the "Now" section
--- Creates the "Now:" section if it doesn't exist
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_to_now(bufnr)
	bufnr = bufnr or 0

	-- Get the current task under the cursor
	local task_text, task_line = task_mover.get_current_task(bufnr)

	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- Determine which section the task is in before deletion
	local current_section = parser.get_section_at_line(task_line, bufnr)
	local section_start, section_end = nil, nil

	if current_section then
		section_start, section_end = parser.get_section_range(current_section, bufnr)
	end

	-- Delete the task from its current location
	task_mover.delete_task_line(task_line, bufnr)

	-- Add the task to the "Now" section
	task_mover.add_task_to_section("Now", task_text, bufnr)

	-- Position cursor intelligently in the original section
	if section_start then
		position_cursor_after_task_move(task_line, section_start, section_end, bufnr)
	else
		-- No section found (shouldn't happen), fall back to staying at current position
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local valid_line = math.min(task_line, #lines)
		if valid_line > 0 then
			vim.api.nvim_win_set_cursor(0, { valid_line, 0 })
		end
	end
end

--- Move the current task to a specified section
--- If section_name is not provided, shows a picker to select the section
--- Removes the task from its current section and adds it to the target section
--- Creates the target section if it doesn't exist
--- @param section_name string|nil The name of the section to move the task to (nil to show picker)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_task_to_section(section_name, bufnr)
	bufnr = bufnr or 0

	-- Validate cursor is on a task BEFORE showing picker
	-- This fails early to avoid showing picker when there's nothing to move
	local task_text, task_line = task_mover.get_current_task(bufnr)
	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- If no section name provided, show picker
	if not section_name or section_name == "" then
		local ui = require("neotodo.ui")
		local sections = parser.get_sections(bufnr)

		if #sections == 0 then
			vim.notify("No sections found in TODO file", vim.log.levels.WARN)
			return
		end

		-- Show picker and recursively call this function with the selected section
		ui.pick_section(sections, function(selected_section_name)
			M.move_task_to_section(selected_section_name, bufnr)
		end, bufnr, "Move Task to Section")
		return
	end

	-- Get the current task under the cursor (again, in case called directly with section_name)
	task_text, task_line = task_mover.get_current_task(bufnr)

	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- Determine which section the task is in before deletion
	local current_section = parser.get_section_at_line(task_line, bufnr)
	local section_start, section_end = nil, nil

	if current_section then
		section_start, section_end = parser.get_section_range(current_section, bufnr)
	end

	-- Delete the task from its current location
	task_mover.delete_task_line(task_line, bufnr)

	-- Add the task to the specified section
	task_mover.add_task_to_section(section_name, task_text, bufnr)

	-- Position cursor intelligently in the original section
	if section_start then
		position_cursor_after_task_move(task_line, section_start, section_end, bufnr)
	else
		-- No section found (shouldn't happen), fall back to staying at current position
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local valid_line = math.min(task_line, #lines)
		if valid_line > 0 then
			vim.api.nvim_win_set_cursor(0, { valid_line, 0 })
		end
	end
end

--- Navigate to a section using a picker
--- Shows a list of all sections and jumps to the selected one
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.navigate_to_section(bufnr)
	bufnr = bufnr or 0
	local ui = require("neotodo.ui")
	local sections = parser.get_sections(bufnr)

	if #sections == 0 then
		vim.notify("No sections found in TODO file", vim.log.levels.WARN)
		return
	end

	-- Show picker and navigate on selection
	ui.pick_section(sections, function(section_name, line)
		vim.api.nvim_win_set_cursor(0, { line, 0 })
	end, bufnr, "Navigate to Section")
end

--- Enable focus mode
--- Hides all sections except "Now" and "Top This Week"
function M.focus_mode_enable()
	focus.focus_mode_enable()
end

--- Disable focus mode
--- Shows all sections
function M.focus_mode_disable()
	focus.focus_mode_disable()
end

--- Toggle focus mode
--- Enables focus mode if disabled, disables if enabled
function M.focus_mode_toggle()
	focus.focus_mode_toggle()
end

return M
