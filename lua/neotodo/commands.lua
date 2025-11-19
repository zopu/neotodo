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
	M.move_task_to_section("Done", bufnr)
end

--- Mark selected tasks (visual mode) as done by moving them to the "Done" section
--- All selected tasks must be in the same section
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.mark_as_done_visual(bufnr)
	M.move_tasks_to_section_visual("Done", bufnr)
end

--- Move the current task to the "Now" section
--- Removes the task from its current section and adds it to the "Now" section
--- Creates the "Now:" section if it doesn't exist
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_to_now(bufnr)
	M.move_task_to_section("Now", bufnr)
end

--- Move selected tasks (visual mode) to the "Now" section
--- All selected tasks must be in the same section
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_to_now_visual(bufnr)
	M.move_tasks_to_section_visual("Now", bufnr)
end

--- Move the current task to a specified section
--- If section_name is not provided, shows a picker to select the section
--- Removes the task from its current section and adds it to the target section
--- Creates the target section if it doesn't exist
--- @param section_name string|nil The name of the section to move the task to (nil to show picker)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_task_to_section(section_name, bufnr)
	bufnr = bufnr or 0

	-- Check if we're in focus mode and get the original buffer
	local original_bufnr, is_focus_mode = focus.get_original_bufnr(bufnr)
	local focus_bufnr = is_focus_mode and bufnr or nil

	-- Get current cursor line and map to original buffer if in focus mode
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local original_line = cursor_line
	if is_focus_mode then
		original_line = focus.map_line_to_original(bufnr, cursor_line)
	end

	-- Validate cursor is on a task BEFORE showing picker
	-- This fails early to avoid showing picker when there's nothing to move
	local task_text, task_line = task_mover.get_current_task(original_bufnr, original_line)
	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- If no section name provided, show picker
	if not section_name or section_name == "" then
		local ui = require("neotodo.ui")
		local sections = parser.get_sections(original_bufnr)

		if #sections == 0 then
			vim.notify("No sections found in TODO file", vim.log.levels.WARN)
			return
		end

		-- Show picker and recursively call this function with the selected section
		ui.pick_section(sections, function(selected_section_name)
			M.move_task_to_section(selected_section_name, bufnr)
		end, original_bufnr, "Move Task to Section")
		return
	end

	-- Get the current task under the cursor (again, in case called directly with section_name)
	task_text, task_line = task_mover.get_current_task(original_bufnr, original_line)

	if not task_text then
		vim.notify("No task found under cursor", vim.log.levels.WARN)
		return
	end

	-- Determine which section the task is in before deletion
	local current_section = parser.get_section_at_line(task_line, original_bufnr)
	local section_start, section_end = nil, nil

	if current_section then
		section_start, section_end = parser.get_section_range(current_section, original_bufnr)
	end

	-- Delete the task from its current location
	task_mover.delete_task_line(task_line, original_bufnr)

	-- Add the task to the specified section
	task_mover.add_task_to_section(section_name, task_text, original_bufnr)

	-- If in focus mode, refresh the focus buffer
	if is_focus_mode and focus_bufnr then
		focus.refresh_focus_buffer(focus_bufnr)
	else
		-- Position cursor intelligently in the original section (only when not in focus mode)
		if section_start then
			position_cursor_after_task_move(task_line, section_start, section_end, original_bufnr)
		else
			-- No section found (shouldn't happen), fall back to staying at current position
			local lines = vim.api.nvim_buf_get_lines(original_bufnr, 0, -1, false)
			local valid_line = math.min(task_line, #lines)
			if valid_line > 0 then
				vim.api.nvim_win_set_cursor(0, { valid_line, 0 })
			end
		end
	end
end

--- Move selected tasks (visual mode) to a specified section
--- If section_name is not provided, shows a picker to select the section
--- All selected tasks must be in the same section
--- @param section_name string|nil The name of the section to move the tasks to (nil to show picker)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.move_tasks_to_section_visual(section_name, bufnr)
	bufnr = bufnr or 0

	-- Check if we're in focus mode and get the original buffer
	local original_bufnr, is_focus_mode = focus.get_original_bufnr(bufnr)
	local focus_bufnr = is_focus_mode and bufnr or nil

	-- Get visual selection range and map to original buffer if in focus mode
	local focus_start, focus_end
	local mode = vim.fn.mode()

	if mode:match('[vV]') then
		focus_start = vim.fn.line("v")
		focus_end = vim.fn.line(".")
		if focus_start > focus_end then
			focus_start, focus_end = focus_end, focus_start
		end
	else
		focus_start = vim.fn.line("'<")
		focus_end = vim.fn.line("'>")
	end

	local original_start, original_end
	if is_focus_mode then
		original_start = focus.map_line_to_original(bufnr, focus_start)
		original_end = focus.map_line_to_original(bufnr, focus_end)
	else
		original_start = focus_start
		original_end = focus_end
	end

	-- Get the visual selection tasks from the original buffer
	local tasks = task_mover.get_visual_selection_tasks(original_bufnr, original_start, original_end)

	if not tasks or #tasks == 0 then
		vim.notify("No tasks found in selection", vim.log.levels.WARN)
		return
	end

	-- Check if all tasks are from the same section (already validated by get_visual_selection_tasks)
	-- If it returned nil, it means the selection spans multiple sections

	-- If no section name provided, show picker
	if not section_name or section_name == "" then
		local ui = require("neotodo.ui")
		local sections = parser.get_sections(original_bufnr)

		if #sections == 0 then
			vim.notify("No sections found in TODO file", vim.log.levels.WARN)
			return
		end

		-- Show picker and recursively call this function with the selected section
		ui.pick_section(sections, function(selected_section_name)
			M.move_tasks_to_section_visual(selected_section_name, bufnr)
		end, original_bufnr, "Move Tasks to Section")
		return
	end

	-- Re-get tasks in case called directly with section_name (picker callback)
	tasks = task_mover.get_visual_selection_tasks(original_bufnr, original_start, original_end)
	if not tasks or #tasks == 0 then
		vim.notify("No tasks found in selection", vim.log.levels.WARN)
		return
	end

	-- Determine which section the tasks are in before deletion
	local first_task_line = tasks[1].line
	local current_section = parser.get_section_at_line(first_task_line, original_bufnr)
	local section_start, section_end = nil, nil

	if current_section then
		section_start, section_end = parser.get_section_range(current_section, original_bufnr)
	end

	-- Collect task texts and line numbers
	local task_texts = {}
	local line_nums = {}
	for _, task in ipairs(tasks) do
		table.insert(task_texts, task.text)
		table.insert(line_nums, task.line)
	end

	-- Delete the tasks from their current location (in reverse order to avoid line shifts)
	task_mover.delete_task_lines(line_nums, original_bufnr)

	-- Add all tasks to the specified section
	task_mover.add_tasks_to_section(section_name, task_texts, original_bufnr)

	-- If in focus mode, refresh the focus buffer
	if is_focus_mode and focus_bufnr then
		focus.refresh_focus_buffer(focus_bufnr)
	else
		-- Position cursor intelligently in the original section (only when not in focus mode)
		-- Adjust section_end for the number of deleted tasks
		if section_start then
			local adjusted_section_end = section_end - #tasks + 1
			position_cursor_after_task_move(first_task_line, section_start, adjusted_section_end, original_bufnr)
		else
			-- No section found (shouldn't happen), fall back to staying at current position
			local lines = vim.api.nvim_buf_get_lines(original_bufnr, 0, -1, false)
			local valid_line = math.min(first_task_line, #lines)
			if valid_line > 0 then
				vim.api.nvim_win_set_cursor(0, { valid_line, 0 })
			end
		end
	end

	vim.notify(string.format("Moved %d task(s) to %s", #tasks, section_name), vim.log.levels.INFO)
end

--- Navigate to a section using a picker
--- Shows a list of all sections and jumps to the selected one
--- Positions cursor on the first task in the section if available, otherwise on the header
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
		-- Get the section range to find the first task
		local start_line, end_line = parser.get_section_range(section_name, bufnr)

		if not start_line then
			-- Fallback to header if range not found
			vim.api.nvim_win_set_cursor(0, { line, 0 })
			return
		end

		-- Search for the first task in this section
		-- Note: nvim_buf_get_lines uses 0-indexed params, but start_line/end_line are 1-indexed
		local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
		local first_task_line = nil

		-- Start from index 2 (skip the header which is at index 1)
		for i = 2, #lines do
			if parser.is_task_line(lines[i]) then
				-- Found the first task, calculate actual line number
				first_task_line = start_line + i - 1
				break
			end
		end

		if first_task_line then
			-- Move to first task at end of line
			local line_content = vim.api.nvim_buf_get_lines(bufnr, first_task_line - 1, first_task_line, false)[1]
			local col = #line_content
			vim.api.nvim_win_set_cursor(0, { first_task_line, col })
		else
			-- No tasks found, stay on section header at end of line
			local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
			local col = #line_content
			vim.api.nvim_win_set_cursor(0, { line, col })
		end
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
