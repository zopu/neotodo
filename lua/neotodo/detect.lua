local M = {}

-- Vim glob patterns matching TODO files, used for autocmds and ftdetect
M.autocmd_patterns = { 'TODO.txt', 'todo.txt', 'TODO_*.txt', 'todo_*.txt' }

-- Check if a bare filename (no directory component) is a TODO file
-- Matches TODO.txt/todo.txt and TODO_<something>.txt/todo_<something>.txt
function M.is_todo_filename(filename)
  return filename == 'TODO.txt' or filename == 'todo.txt'
      or filename:match('^TODO_.+%.txt$') ~= nil
      or filename:match('^todo_.+%.txt$') ~= nil
end

-- Check if a buffer holds a TODO file
-- Handles full paths as well as focus buffers, which are named "<name> [Focus]"
function M.is_todo_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Handle empty buffer names (unnamed buffers)
  if bufname == '' then
    return false
  end

  local name = bufname:gsub('%s*%[Focus%]$', '')

  return M.is_todo_filename(vim.fn.fnamemodify(name, ':t'))
end

return M
