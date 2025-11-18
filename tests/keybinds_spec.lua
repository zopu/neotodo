describe("keybinds", function()
  local keybinds = require('neotodo.keybinds')
  local config = require('neotodo.config')

  before_each(function()
    -- Reset config to defaults before each test
    config.options = vim.deepcopy(config.defaults)
  end)

  after_each(function()
    -- Close any open buffers
    vim.cmd('bufdo! bwipeout!')
  end)

  it("sets up buffer-local keybindings for TODO.txt", function()
    -- Create a TODO.txt buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'TODO.txt')

    -- Configure some keybinds
    config.options.keybinds = {
      add_task = '<leader>ta',
      mark_done = '<leader>td',
    }

    -- Set up keybindings
    keybinds.setup_buffer_keybinds(0)

    -- Check that keymaps exist for this buffer by checking descriptions
    -- (lhs will be resolved to actual leader key, not the string '<leader>ta')
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_add_task = false
    local has_mark_done = false
    for _, map in ipairs(maps) do
      if map.desc and map.desc:match('Add new task') then has_add_task = true end
      if map.desc and map.desc:match('Mark current task') then has_mark_done = true end
    end
    assert.is_true(has_add_task, "Expected add_task keybind to be set")
    assert.is_true(has_mark_done, "Expected mark_done keybind to be set")
  end)

  it("does not set keybinds in non-TODO buffers", function()
    -- Create a non-TODO buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'other.txt')

    -- Configure some keybinds
    config.options.keybinds = {
      add_task = '<leader>ta',
    }

    -- Try to set up keybindings
    keybinds.setup_buffer_keybinds(0)

    -- Check that keymaps were NOT added (check by description)
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_add_task = false
    for _, map in ipairs(maps) do
      if map.desc and map.desc:match('Add new task') then has_add_task = true end
    end
    assert.is_false(has_add_task, "Expected add_task keybind NOT to be set in non-TODO buffer")
  end)

  it("only sets keybinds that are configured (not nil)", function()
    -- Create a TODO.txt buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'TODO.txt')

    -- Configure only one keybind
    config.options.keybinds = {
      add_task = '<leader>ta',
      mark_done = nil, -- Not configured
    }

    -- Set up keybindings
    keybinds.setup_buffer_keybinds(0)

    -- Check that only configured keymaps exist (check by description)
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_add_task = false
    local has_mark_done = false
    for _, map in ipairs(maps) do
      if map.desc and map.desc:match('Add new task') then has_add_task = true end
      if map.desc and map.desc:match('Mark current task') then has_mark_done = true end
    end
    assert.is_true(has_add_task, "Expected add_task keybind to be set")
    assert.is_false(has_mark_done, "Expected mark_done keybind NOT to be set when nil")
  end)

  it("sets all available keybinds when configured", function()
    -- Create a TODO.txt buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'TODO.txt')

    -- Configure all keybinds
    config.options.keybinds = {
      add_task = '<leader>ta',
      mark_done = '<leader>td',
      move_to_now = '<leader>tn',
      move_to_section = '<leader>ts',
      move_task = '<leader>tm',
      focus_enable = '<leader>fe',
      focus_disable = '<leader>fd',
      focus_toggle = '<leader>ft',
    }

    -- Set up keybindings
    keybinds.setup_buffer_keybinds(0)

    -- Check that all keymaps exist by checking their descriptions
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local keybinds_found = {
      add_task = false,
      mark_done = false,
      move_to_now = false,
      move_to_section = false,
      move_task = false,
      focus_enable = false,
      focus_disable = false,
      focus_toggle = false,
    }

    -- Match descriptions to keybinds
    for _, map in ipairs(maps) do
      if map.desc then
        if map.desc:match('Add new task') then keybinds_found.add_task = true end
        if map.desc:match('Mark current task') then keybinds_found.mark_done = true end
        if map.desc:match('Move current task to Now') then keybinds_found.move_to_now = true end
        if map.desc:match('Navigate to section') then keybinds_found.move_to_section = true end
        if map.desc:match('Move task to section') then keybinds_found.move_task = true end
        if map.desc:match('Enable focus mode') then keybinds_found.focus_enable = true end
        if map.desc:match('Disable focus mode') then keybinds_found.focus_disable = true end
        if map.desc:match('Toggle focus mode') then keybinds_found.focus_toggle = true end
      end
    end

    for key, found in pairs(keybinds_found) do
      assert.is_true(found, "Expected keybind " .. key .. " to be set")
    end
  end)

  it("sets up keybindings for lowercase todo.txt", function()
    -- Create a lowercase todo.txt buffer
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, 'todo.txt')

    -- Configure some keybinds
    config.options.keybinds = {
      add_task = '<leader>ta',
      mark_done = '<leader>td',
    }

    -- Set up keybindings
    keybinds.setup_buffer_keybinds(0)

    -- Check that keymaps exist for this buffer
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_add_task = false
    local has_mark_done = false
    for _, map in ipairs(maps) do
      if map.desc and map.desc:match('Add new task') then has_add_task = true end
      if map.desc and map.desc:match('Mark current task') then has_mark_done = true end
    end
    assert.is_true(has_add_task, "Expected add_task keybind to be set for todo.txt")
    assert.is_true(has_mark_done, "Expected mark_done keybind to be set for todo.txt")
  end)
end)
