-- task_mover.lua: Shared utilities for moving tasks between sections

local parser = require('neotodo.parser')

local M = {}

--- Get the current task under the cursor (or at a specific line)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @param line_num number|nil Optional line number (uses cursor position if not provided)
--- @return string|nil, number|nil Task text and line number, or nil if not on a task
function M.get_current_task(bufnr, line_num)
  bufnr = bufnr or 0
  if not line_num then
    local cursor = vim.api.nvim_win_get_cursor(0)
    line_num = cursor[1]
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return nil, nil
  end

  local line = lines[1]

  -- Check if this is actually a task line
  if not parser.is_task_line(line) then
    return nil, nil
  end

  return line, line_num
end

--- Get selected tasks in visual mode
--- Returns nil if the selection spans multiple sections
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @param override_start number|nil Optional start line (uses visual selection if not provided)
--- @param override_end number|nil Optional end line (uses visual selection if not provided)
--- @return table|nil Array of {text = string, line = number}, or nil if selection invalid
function M.get_visual_selection_tasks(bufnr, override_start, override_end)
  bufnr = bufnr or 0

  local start_line, end_line

  if override_start and override_end then
    -- Use provided line range
    start_line = override_start
    end_line = override_end
  else
    -- Get visual selection range
    -- Use mode() to check if we're still in visual mode
    local mode = vim.fn.mode()

    if mode:match('[vV]') then
      -- Still in visual mode - use current visual selection positions
      start_line = vim.fn.line("v")  -- Start of visual selection
      end_line = vim.fn.line(".")    -- Current cursor position
      -- Ensure start <= end
      if start_line > end_line then
        start_line, end_line = end_line, start_line
      end
    else
      -- Not in visual mode - use marks from last visual selection
      start_line = vim.fn.line("'<")
      end_line = vim.fn.line("'>")
    end
  end

  -- Get all lines in the selection
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    return nil
  end

  -- Collect all tasks in the selection
  local tasks = {}
  local section_for_first_task = nil

  for i, line in ipairs(lines) do
    local line_num = start_line + i - 1

    if parser.is_task_line(line) then
      -- Determine which section this task belongs to
      local section = parser.get_section_at_line(line_num, bufnr)

      if section_for_first_task == nil then
        -- This is the first task we've found
        section_for_first_task = section
      elseif section ~= section_for_first_task then
        -- Task is in a different section, return nil
        return nil
      end

      table.insert(tasks, {
        text = line,
        line = line_num
      })
    end
  end

  return #tasks > 0 and tasks or nil
end

--- Delete a task line from the buffer
--- @param line_num number Line number to delete (1-indexed)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.delete_task_line(line_num, bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {})
end

--- Delete multiple task lines from the buffer
--- Lines should be sorted in descending order to avoid line number shifts
--- @param line_nums table Array of line numbers to delete (1-indexed)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.delete_task_lines(line_nums, bufnr)
  bufnr = bufnr or 0

  -- Sort line numbers in descending order to delete from bottom up
  -- This prevents line number shifts from affecting subsequent deletions
  local sorted_lines = {}
  for _, line_num in ipairs(line_nums) do
    table.insert(sorted_lines, line_num)
  end
  table.sort(sorted_lines, function(a, b) return a > b end)

  -- Delete each line
  for _, line_num in ipairs(sorted_lines) do
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {})
  end
end

--- Add a task to a section (appends at the end of the section)
--- @param section_name string The section to add the task to
--- @param task_text string The task text (should be indented)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.add_task_to_section(section_name, task_text, bufnr)
  bufnr = bufnr or 0

  -- Ensure the section exists first
  M.ensure_section_exists(section_name, bufnr)

  local start_line, end_line = parser.get_section_range(section_name, bufnr)

  if not start_line then
    error("Section not found: " .. section_name)
  end

  -- Find the last non-empty line in the section
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local insert_line = start_line -- Start after the header

  -- Find the last task line in this section
  for i = #lines, 1, -1 do
    local line = lines[i]
    if parser.is_task_line(line) or parser.is_section_header(line) then
      insert_line = start_line - 1 + i
      break
    end
  end

  -- Insert the task after the last task or after the header
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, {task_text})
end

--- Add multiple tasks to a section (appends all at the end of the section)
--- @param section_name string The section to add the tasks to
--- @param task_texts table Array of task text strings (should be indented)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.add_tasks_to_section(section_name, task_texts, bufnr)
  bufnr = bufnr or 0

  if #task_texts == 0 then
    return
  end

  -- Ensure the section exists first
  M.ensure_section_exists(section_name, bufnr)

  local start_line, end_line = parser.get_section_range(section_name, bufnr)

  if not start_line then
    error("Section not found: " .. section_name)
  end

  -- Find the last non-empty line in the section
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local insert_line = start_line -- Start after the header

  -- Find the last task line in this section
  for i = #lines, 1, -1 do
    local line = lines[i]
    if parser.is_task_line(line) or parser.is_section_header(line) then
      insert_line = start_line - 1 + i
      break
    end
  end

  -- Insert all tasks at once after the last task or after the header
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, task_texts)
end

--- Ensure a section exists in the buffer, creating it if necessary
--- @param section_name string The section name to ensure exists
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.ensure_section_exists(section_name, bufnr)
  bufnr = bufnr or 0
  local sections = parser.get_sections(bufnr)

  -- Check if section already exists
  for _, section in ipairs(sections) do
    if section.name == section_name then
      return -- Section already exists
    end
  end

  -- Section doesn't exist, create it
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local section_header = section_name .. ":"

  -- Add section at the end of the file
  -- If the last line is not empty, add a blank line first
  local last_line = vim.api.nvim_buf_get_lines(bufnr, total_lines - 1, total_lines, false)[1]

  if last_line and last_line ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, total_lines, total_lines, false, {"", section_header})
  else
    vim.api.nvim_buf_set_lines(bufnr, total_lines, total_lines, false, {section_header})
  end
end

return M
