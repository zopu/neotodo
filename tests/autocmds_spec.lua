describe("autocmds", function()
  local autocmds = require('neotodo.autocmds')

  before_each(function()
    -- Clear any existing autocommands
    vim.api.nvim_create_augroup('NeoTodo', { clear = true })
  end)

  after_each(function()
    -- Clean up buffers
    vim.cmd('bufdo! bwipeout!')
  end)

  it("creates autocommand group", function()
    autocmds.setup()

    -- Check that the NeoTodo autocommand group exists
    local groups = vim.api.nvim_get_autocmds({ group = "NeoTodo" })
    assert.is_true(#groups > 0, "Expected NeoTodo autocommand group to be created")
  end)

  it("creates BufEnter autocmd for TODO.txt", function()
    autocmds.setup()

    local groups = vim.api.nvim_get_autocmds({ group = "NeoTodo", event = "BufEnter" })
    assert.is_true(#groups > 0, "Expected BufEnter autocmd to exist")

    -- Check that it has the right pattern
    local has_todo_pattern = false
    for _, autocmd in ipairs(groups) do
      if autocmd.pattern == "TODO.txt" then
        has_todo_pattern = true
        break
      end
    end
    assert.is_true(has_todo_pattern, "Expected BufEnter autocmd to match TODO.txt pattern")
  end)

  it("creates BufLeave autocmd for TODO.txt", function()
    autocmds.setup()

    local groups = vim.api.nvim_get_autocmds({ group = "NeoTodo", event = "BufLeave" })
    assert.is_true(#groups > 0, "Expected BufLeave autocmd to exist")

    -- Check that it has the right pattern
    local has_todo_pattern = false
    for _, autocmd in ipairs(groups) do
      if autocmd.pattern == "TODO.txt" then
        has_todo_pattern = true
        break
      end
    end
    assert.is_true(has_todo_pattern, "Expected BufLeave autocmd to match TODO.txt pattern")
  end)

  it("applies keybindings when entering TODO.txt buffer", function()
    local config = require('neotodo.config')

    -- Configure a keybind
    config.options.keybinds = {
      add_task = '<leader>ta',
    }

    -- Set up autocmds
    autocmds.setup()

    -- Create and enter a TODO.txt buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'TODO.txt')
    vim.cmd('doautocmd BufEnter')

    -- Check that the keybind was applied
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_keybind = false
    for _, map in ipairs(maps) do
      if map.desc and map.desc:match('Add new task') then
        has_keybind = true
        break
      end
    end
    assert.is_true(has_keybind, "Expected keybindings to be applied on BufEnter")
  end)

  it("clears and recreates autocommand group on repeated setup", function()
    autocmds.setup()
    local groups_first = vim.api.nvim_get_autocmds({ group = "NeoTodo" })
    local count_first = #groups_first

    -- Setup again - should clear and recreate
    autocmds.setup()
    local groups_second = vim.api.nvim_get_autocmds({ group = "NeoTodo" })
    local count_second = #groups_second

    -- Should have the same number of autocmds (cleared and recreated, not duplicated)
    assert.equals(count_first, count_second, "Expected autocommands to be cleared and recreated, not duplicated")
  end)
end)
