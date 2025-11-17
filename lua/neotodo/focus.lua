local M = {}

local parser = require('neotodo.parser')
local config = require('neotodo.config')

-- Create namespace for extmarks
local ns_id = vim.api.nvim_create_namespace('neotodo_focus')

-- Check if a section should be folded in focus mode
-- Reads from config to determine which sections should remain visible
function M.should_fold_section(section_name)
  for _, focused_section in ipairs(config.options.focus_sections) do
    if focused_section == section_name then
      return false  -- Don't fold this section
    end
  end
  return true  -- Fold all other sections
end

-- Check if focus mode is currently enabled
function M.is_focus_mode_enabled()
  return vim.b.neotodo_focus_mode == true
end

-- Get filtered buffer content (only visible sections)
local function get_filtered_content(bufnr)
  bufnr = bufnr or 0
  local sections = parser.get_sections(bufnr)
  local filtered_lines = {}

  for _, section in ipairs(sections) do
    if not M.should_fold_section(section.name) then
      -- This section should be visible
      local start_line, end_line = parser.get_section_range(section.name, bufnr)
      if start_line and end_line then
        local section_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        for _, line in ipairs(section_lines) do
          table.insert(filtered_lines, line)
        end
      end
    end
  end

  return filtered_lines
end

-- Map cursor position from original buffer to focus buffer
local function map_cursor_to_focus(bufnr, cursor_pos)
  local row, col = cursor_pos[1], cursor_pos[2]
  local sections = parser.get_sections(bufnr)
  local focus_row = 1

  -- Find which section the cursor is in
  local current_section = parser.get_section_at_line(row, bufnr)

  -- Count lines in visible sections before the cursor
  for _, section in ipairs(sections) do
    if not M.should_fold_section(section.name) then
      local start_line, end_line = parser.get_section_range(section.name, bufnr)
      if start_line and end_line then
        if section.name == current_section and row >= start_line and row <= end_line then
          -- Cursor is in this visible section
          focus_row = focus_row + (row - start_line)
          return { focus_row, col }
        elseif end_line < row then
          -- Add this section's lines to the count
          focus_row = focus_row + (end_line - start_line + 1)
        end
      end
    end
  end

  -- Default to first line if mapping fails
  return { 1, 0 }
end

-- Map cursor position from focus buffer back to original buffer
local function map_cursor_from_focus(original_bufnr, focus_row)
  local sections = parser.get_sections(original_bufnr)
  local current_focus_row = 1

  -- Find which visible section the cursor is in
  for _, section in ipairs(sections) do
    if not M.should_fold_section(section.name) then
      local start_line, end_line = parser.get_section_range(section.name, original_bufnr)
      if start_line and end_line then
        local section_length = end_line - start_line + 1
        if focus_row <= current_focus_row + section_length - 1 then
          -- Cursor is in this section
          local offset = focus_row - current_focus_row
          return start_line + offset
        end
        current_focus_row = current_focus_row + section_length
      end
    end
  end

  -- Default to first line if mapping fails
  return 1
end

-- Enable focus mode for the current buffer
function M.focus_mode_enable()
  local original_bufnr = vim.api.nvim_get_current_buf()

  -- Get filtered content (only visible sections)
  local filtered_lines = get_filtered_content(original_bufnr)

  -- Get current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  -- Create a new scratch buffer
  local focus_bufnr = vim.api.nvim_create_buf(false, true)

  -- Set scratch buffer options
  vim.bo[focus_bufnr].buftype = 'nofile'
  vim.bo[focus_bufnr].bufhidden = 'wipe'
  vim.bo[focus_bufnr].filetype = 'neotodo'
  vim.bo[focus_bufnr].swapfile = false

  -- Set buffer name
  local original_name = vim.api.nvim_buf_get_name(original_bufnr)
  local focus_name = original_name .. ' [Focus]'
  vim.api.nvim_buf_set_name(focus_bufnr, focus_name)

  -- Write filtered content to scratch buffer
  vim.api.nvim_buf_set_lines(focus_bufnr, 0, -1, false, filtered_lines)

  -- Make buffer read-only
  vim.bo[focus_bufnr].modifiable = false

  -- Store buffer references
  vim.api.nvim_buf_set_var(focus_bufnr, 'neotodo_original_bufnr', original_bufnr)
  vim.api.nvim_buf_set_var(original_bufnr, 'neotodo_focus_bufnr', focus_bufnr)

  -- Mark focus mode as enabled
  vim.api.nvim_buf_set_var(focus_bufnr, 'neotodo_focus_mode', true)

  -- Set up keybinds manually since focus buffer name doesn't match TODO.txt pattern
  local keybinds = require('neotodo.keybinds')
  keybinds.setup_buffer_keybinds(focus_bufnr)

  -- Switch to focus buffer
  vim.api.nvim_win_set_buf(0, focus_bufnr)

  -- Map and set cursor position
  local focus_cursor = map_cursor_to_focus(original_bufnr, cursor_pos)
  vim.api.nvim_win_set_cursor(0, focus_cursor)
end

-- Disable focus mode for the current buffer
function M.focus_mode_disable()
  local focus_bufnr = vim.api.nvim_get_current_buf()

  -- Get original buffer number
  local ok, original_bufnr = pcall(vim.api.nvim_buf_get_var, focus_bufnr, 'neotodo_original_bufnr')
  if not ok or not vim.api.nvim_buf_is_valid(original_bufnr) then
    -- If we can't find the original buffer, just return
    return
  end

  -- Get current cursor position in focus buffer
  local focus_cursor = vim.api.nvim_win_get_cursor(0)
  local focus_row = focus_cursor[1]

  -- Map cursor position back to original buffer
  local original_row = map_cursor_from_focus(original_bufnr, focus_row)

  -- Switch back to original buffer
  vim.api.nvim_win_set_buf(0, original_bufnr)

  -- Set cursor position in original buffer
  local original_col = focus_cursor[2]
  pcall(vim.api.nvim_win_set_cursor, 0, { original_row, original_col })

  -- Focus buffer will be auto-deleted due to bufhidden=wipe
end

-- Called when entering a TODO.txt buffer (no-op for scratch buffer approach)
function M.on_buf_enter() end

-- Called when leaving a TODO.txt buffer (no-op for scratch buffer approach)
function M.on_buf_leave() end

-- Toggle focus mode
function M.focus_mode_toggle()
  if M.is_focus_mode_enabled() then
    M.focus_mode_disable()
  else
    M.focus_mode_enable()
  end
end

return M
