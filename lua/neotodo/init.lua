-- init.lua - Main entry point for NeoTODO plugin

local M = {}

-- Plugin version
M.version = "0.1.0"

-- Setup function called by users in their config
function M.setup(user_config)
  local config = require("neotodo.config")

  -- Merge user configuration with defaults
  config.setup(user_config or {})

  -- Future commits will add:
  -- - Command registration
  -- - Autocommand setup
  -- - Keybinding configuration
end

return M
