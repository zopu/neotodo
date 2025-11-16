-- parser.lua: Core functions to parse TODO.txt file structure

local M = {}

--- Check if a line is a section header (ends with ':')
--- @param line string The line to check
--- @return boolean True if the line is a section header
function M.is_section_header(line)
  if not line or line == "" then
    return false
  end
  -- Trim trailing whitespace and check if it ends with ':'
  local trimmed = line:match("^(.-)%s*$")
  return trimmed:sub(-1) == ":"
end

--- Check if a line is a task (indented)
--- @param line string The line to check
--- @return boolean True if the line is indented (a task)
function M.is_task_line(line)
  if not line or line == "" then
    return false
  end
  -- Check if line starts with whitespace (indented)
  return line:match("^%s+") ~= nil
end

--- Get all sections with their line numbers from the current buffer
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @return table Array of {name = string, line = number}
function M.get_sections(bufnr)
  bufnr = bufnr or 0
  local sections = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    if M.is_section_header(line) then
      -- Extract section name (everything before the ':')
      local name = line:match("^(.-)%s*:%s*$")
      if name then
        table.insert(sections, {
          name = name,
          line = i
        })
      end
    end
  end

  return sections
end

--- Get which section a specific line belongs to
--- @param line_num number Line number (1-indexed)
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @return string|nil Section name or nil if not in any section
function M.get_section_at_line(line_num, bufnr)
  bufnr = bufnr or 0
  local sections = M.get_sections(bufnr)

  if #sections == 0 then
    return nil
  end

  -- Find the section this line belongs to
  -- It belongs to the last section header before this line
  local current_section = nil
  for _, section in ipairs(sections) do
    if section.line <= line_num then
      current_section = section.name
    else
      break
    end
  end

  return current_section
end

--- Get the line range for a section
--- @param section_name string The section name to find
--- @param bufnr number|nil Buffer number (0 or nil for current buffer)
--- @return number|nil, number|nil Start line, end line (1-indexed) or nil if not found
function M.get_section_range(section_name, bufnr)
  bufnr = bufnr or 0
  local sections = M.get_sections(bufnr)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Find the section
  local section_index = nil
  for i, section in ipairs(sections) do
    if section.name == section_name then
      section_index = i
      break
    end
  end

  if not section_index then
    return nil, nil
  end

  local start_line = sections[section_index].line
  local end_line

  -- End line is either the line before the next section, or end of file
  if section_index < #sections then
    end_line = sections[section_index + 1].line - 1
  else
    end_line = total_lines
  end

  return start_line, end_line
end

return M
