-- init.lua - Main entry point for NeoTODO plugin

local M = {}

-- Plugin version
M.version = "0.1.0"

-- Setup function called by users in their config
function M.setup(user_config)
  local config = require("neotodo.config")

  -- Merge user configuration with defaults
  config.setup(user_config or {})

  -- Register commands
  local commands = require("neotodo.commands")
  vim.api.nvim_create_user_command("NeoTodoAddTask", function()
    commands.add_task()
  end, { desc = "Add a new task to the New section" })

  vim.api.nvim_create_user_command("NeoTodoMarkAsDone", function()
    commands.mark_as_done()
  end, { desc = "Mark the current task as done" })

  vim.api.nvim_create_user_command("NeoTodoMoveTaskToSection", function(opts)
    commands.move_task_to_section(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Move the current task to a specified section (shows picker if no section provided)"
  })

  vim.api.nvim_create_user_command("NeoTodoNavigateToSection", function()
    commands.navigate_to_section()
  end, { desc = "Navigate to a section using a picker" })

  -- Future commits will add:
  -- - More command registration
  -- - Autocommand setup
  -- - Keybinding configuration
end

return M
