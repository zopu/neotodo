local M = {}

-- Set up autocommands for neotodo
function M.setup()
  local focus = require('neotodo.focus')

  -- Create autocommand group
  local group = vim.api.nvim_create_augroup('NeoTodo', { clear = true })

  -- Apply/restore focus mode settings when entering/leaving TODO.txt buffers
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = 'TODO.txt',
    callback = function()
      focus.on_buf_enter()
    end,
    desc = 'Apply focus mode settings when entering TODO.txt buffer',
  })

  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    pattern = 'TODO.txt',
    callback = function()
      focus.on_buf_leave()
    end,
    desc = 'Reset fold settings when leaving TODO.txt buffer',
  })
end

return M
