local M = {}

-- Set up autocommands for neotodo
function M.setup()
  local focus = require('neotodo.focus')
  local keybinds = require('neotodo.keybinds')
  local detect = require('neotodo.detect')

  -- Create autocommand group
  local group = vim.api.nvim_create_augroup('NeoTodo', { clear = true })

  -- Apply/restore focus mode settings and keybindings when entering TODO buffers
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = detect.autocmd_patterns,
    callback = function(ev)
      -- Disable spell checking in TODO buffers
      vim.opt_local.spell = false

      focus.on_buf_enter()
      keybinds.setup_buffer_keybinds(ev.buf)
    end,
    desc = 'Apply focus mode settings and keybindings when entering TODO.txt buffer',
  })

  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    pattern = detect.autocmd_patterns,
    callback = function()
      focus.on_buf_leave()
    end,
    desc = 'Reset fold settings when leaving TODO.txt buffer',
  })
end

return M
