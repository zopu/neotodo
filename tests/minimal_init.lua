-- minimal_init.lua - Minimal Neovim configuration for testing

-- Add current plugin to runtime path
vim.opt.rtp:append(".")

-- Add plenary.nvim to runtime path
-- Assumes plenary is installed in standard locations
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
  -- Try site package location
  plenary_path = vim.fn.stdpath("data") .. "/site/pack/plenary/start/plenary.nvim"
end

if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.rtp:append(plenary_path)
else
  -- Print warning if plenary not found
  vim.notify(
    "plenary.nvim not found. Install it with:\n"
      .. "  git clone https://github.com/nvim-lua/plenary.nvim "
      .. vim.fn.stdpath("data")
      .. "/site/pack/plenary/start/plenary.nvim",
    vim.log.levels.WARN
  )
end

-- Disable swap files and other unnecessary features for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Set up plenary's test harness if available
local has_plenary, plenary = pcall(require, "plenary.busted")
if not has_plenary then
	error("plenary.nvim is required for testing. Install it with:\n"
		.. "  git clone https://github.com/nvim-lua/plenary.nvim "
		.. vim.fn.stdpath("data") .. "/site/pack/plenary/start/plenary.nvim")
end
