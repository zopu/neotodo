local M = {}

local parser = require('neotodo.parser')

-- Create namespace for extmarks
local ns_id = vim.api.nvim_create_namespace('neotodo_focus')

-- Sections that should remain visible in focus mode
local FOCUSED_SECTIONS = {
  ["Now"] = true,
  ["Top This Week"] = true,
}

-- Check if a section should be folded in focus mode
function M.should_fold_section(section_name)
  return not FOCUSED_SECTIONS[section_name]
end

-- Check if focus mode is currently enabled
function M.is_focus_mode_enabled()
  return vim.b.neotodo_focus_mode == true
end

-- Fold expression function for focus mode
-- Returns fold level for each line
local function focus_fold_expr(lnum)
  local line = vim.fn.getline(lnum)

  -- Check if this is a section header
  if parser.is_section_header(line) then
    local section_name = line:match("^(.-):%s*$")
    if section_name and M.should_fold_section(section_name) then
      return ">1"  -- Start a fold
    else
      return "0"   -- No fold for focused sections
    end
  end

  -- For non-header lines, check if we're in a folded section
  local section = parser.get_section_at_line(lnum)
  if section and M.should_fold_section(section) then
    return "1"  -- Continue the fold
  end

  return "0"  -- No fold
end

-- Hide section headers using extmarks
-- Uses conceal to make foldable section headers invisible
local function hide_section_headers(bufnr)
  bufnr = bufnr or 0

  -- Get all sections in the buffer
  local sections = parser.get_sections(bufnr)

  -- For each section that should be folded, hide its header
  for _, section in ipairs(sections) do
    if M.should_fold_section(section.name) then
      -- Use extmark to conceal the section header line
      -- line is 1-indexed, but extmarks use 0-indexed rows
      local row = section.line - 1

      -- Get the actual line to determine its length
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      local line_length = #line

      -- Conceal the entire line
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
        end_row = row + 1,      -- End at the next line (covers the whole line)
        end_col = 0,            -- End at column 0 of next line
        conceal = '',           -- Conceal with empty string (makes it invisible)
      })
    end
  end
end

-- Clear all section header extmarks
local function clear_section_headers(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

-- Apply focus mode fold settings to current window
local function apply_focus_folds(bufnr)
  bufnr = bufnr or 0

  -- Set up folding
  vim.wo.foldmethod = "expr"
  vim.wo.foldexpr = "v:lua.require('neotodo.focus')._fold_expr(v:lnum)"
  vim.wo.foldenable = true
  vim.wo.foldlevel = 0  -- Close all folds by default

  -- Enable concealment to hide section headers
  vim.wo.conceallevel = 3  -- Completely hide concealed text
  vim.wo.concealcursor = ''  -- Don't reveal when cursor is on the line

  -- Force fold update
  vim.cmd('normal! zx')

  -- Save current cursor position
  local saved_cursor = vim.api.nvim_win_get_cursor(0)

  -- Close only the sections that should be folded
  local sections = parser.get_sections(bufnr)
  for _, section in ipairs(sections) do
    if M.should_fold_section(section.name) then
      vim.fn.cursor(section.line, 1)
      vim.cmd('normal! zc')
    end
  end

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(0, saved_cursor)

  -- Hide section headers using extmarks
  hide_section_headers(bufnr)
end

-- Enable focus mode for the current buffer
function M.focus_mode_enable()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Mark focus mode as enabled for this buffer
  vim.b.neotodo_focus_mode = true

  -- Apply the fold settings and hide headers
  apply_focus_folds(bufnr)
end

-- Disable focus mode for the current buffer
function M.focus_mode_disable()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear extmarks that hide section headers
  clear_section_headers(bufnr)

  -- Clear focus mode flag
  vim.b.neotodo_focus_mode = false

  -- Reset to normal folding
  vim.wo.foldmethod = "manual"
  vim.wo.foldenable = false
  vim.wo.foldlevel = 99

  -- Reset concealment
  vim.wo.conceallevel = 0
  vim.wo.concealcursor = ''

  -- Unfold everything
  vim.cmd('normal! zR')
end

-- Called when entering a TODO.txt buffer
-- Applies focus mode settings if enabled for this buffer
function M.on_buf_enter()
  if M.is_focus_mode_enabled() then
    local bufnr = vim.api.nvim_get_current_buf()
    apply_focus_folds(bufnr)
  end
end

-- Called when leaving a TODO.txt buffer
-- Resets window fold settings to defaults
function M.on_buf_leave()
  -- Only reset if we had focus mode enabled
  if M.is_focus_mode_enabled() then
    local bufnr = vim.api.nvim_get_current_buf()

    -- Clear extmarks when leaving (they'll be reapplied on BufEnter)
    clear_section_headers(bufnr)

    -- Reset window fold settings to sensible defaults for other buffers
    vim.wo.foldmethod = "manual"
    vim.wo.foldenable = false
    vim.wo.foldlevel = 99
    vim.wo.conceallevel = 0
    vim.wo.concealcursor = ''
  end
end

-- Toggle focus mode
function M.focus_mode_toggle()
  if M.is_focus_mode_enabled() then
    M.focus_mode_disable()
  else
    M.focus_mode_enable()
  end
end

-- Fold expression function (exposed for foldexpr)
function M._fold_expr(lnum)
  return focus_fold_expr(lnum)
end

return M
