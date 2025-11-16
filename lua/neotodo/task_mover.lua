-- task_mover.lua: Shared utilities for moving tasks between sections

local parser = require('neotodo.parser')

local M = {}

--- Get the current task under the cursor
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @return string|nil, number|nil Task text and line number, or nil if not on a task
function M.get_current_task(bufnr)
  bufnr = bufnr or 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

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

--- Delete a task line from the buffer
--- @param line_num number Line number to delete (1-indexed)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
function M.delete_task_line(line_num, bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {})
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
