local M = {}

-- Check if buffer should have TODO keybindings
local function is_todo_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Handle empty buffer names (unnamed buffers)
  if bufname == '' then
    return false
  end

  local filename = vim.fn.fnamemodify(bufname, ':t')

  local config = require('neotodo.config')
  local pattern = config.options.file_pattern

  -- Match the pattern - check both the full name and the basename
  -- This handles both "TODO.txt" and "/path/to/TODO.txt"
  return filename == pattern or bufname == pattern
end

-- Set up buffer-local keybindings for a TODO.txt buffer
function M.setup_buffer_keybinds(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Only apply keybinds if this is a TODO buffer
  if not is_todo_buffer(bufnr) then
    return
  end

  local config = require('neotodo.config')
  local commands = require('neotodo.commands')
  local keybinds = config.options.keybinds

  -- Set up each keybinding if it's defined (not nil)
  if keybinds.add_task then
    vim.keymap.set('n', keybinds.add_task, function()
      commands.add_task()
    end, {
      buffer = bufnr,
      desc = 'Add new task to New section',
      silent = true,
    })
  end

  if keybinds.mark_done then
    vim.keymap.set('n', keybinds.mark_done, function()
      commands.mark_as_done()
    end, {
      buffer = bufnr,
      desc = 'Mark current task as done',
      silent = true,
    })
  end

  if keybinds.move_to_section then
    vim.keymap.set('n', keybinds.move_to_section, function()
      commands.navigate_to_section()
    end, {
      buffer = bufnr,
      desc = 'Navigate to section',
      silent = true,
    })
  end

  if keybinds.move_task then
    vim.keymap.set('n', keybinds.move_task, function()
      commands.move_task_to_section()
    end, {
      buffer = bufnr,
      desc = 'Move task to section',
      silent = true,
    })
  end

  if keybinds.focus_enable then
    vim.keymap.set('n', keybinds.focus_enable, function()
      commands.focus_mode_enable()
    end, {
      buffer = bufnr,
      desc = 'Enable focus mode',
      silent = true,
    })
  end

  if keybinds.focus_disable then
    vim.keymap.set('n', keybinds.focus_disable, function()
      commands.focus_mode_disable()
    end, {
      buffer = bufnr,
      desc = 'Disable focus mode',
      silent = true,
    })
  end
end

return M
