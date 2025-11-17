# NeoTODO

[![Tests](https://github.com/zopu/neotodo/actions/workflows/test.yml/badge.svg)](https://github.com/zopu/neotodo/actions/workflows/test.yml)

A plugin to aid with editing of TODO.txt files in Neovim using an opinionated structure.

A todo file for this plugin is a text file with section headers (with a colon suffix) followed by an indented list of tasks.

```
New:
  something I just thought of

This week:
  thing 1
  thing 2

Top This Week:
  Most important task for this week
  Second most important task for this week

Today:
  fairly urgent job to be done

Blocked:
  A task that can't be done yet
  A task waiting on someone else

Now:
  a task I'm currently working on
  another task
```

Arbitrary sections headers are supported, but some are required and have special meaning:
- "New" - New tasks are added here by default.
- "Now" - Tasks are moved heen when started.
- "Top This Week" - Is not hidden when in a focus mode.
- "Done" - Completed tasks are moved here.

This plugin provides commands to manipulate tasks and sections, move quickly between sections, and focus/hide sections.

## Basic Commands

- "MoveToSection" - opens an fzf picker to move the cursor to a section.
- "MarkAsDone" - moves a task to the "Done" section.
- "FocusModeEnable" - hides all sections except the "Now" and "Top This Week" sections.
- "FocusModeDisable" - shows all sections again.
- "AddTask" - Adds a new line to the "New" section and places the cursor there in insert mode.

Keybinds for these commands can be set in the plugin setup. These keybinds will only be active when editing a file called TODO.txt.

## Installation

### lazy.nvim

```lua
{
  "zopu/neotodo",
  ft = "todo",  -- Lazy load on TODO.txt files
  config = function()
    require("neotodo").setup({
      keybinds = {
        add_task = "<leader>ta",
        mark_done = "<leader>td",
        move_task = "<leader>tm",
        navigate_to_section = "<leader>ts",
        focus_mode_enable = "<leader>tf",
        focus_mode_disable = "<leader>tF",
      }
    })
  end,
}
```

### packer.nvim

```lua
use {
  "zopu/neotodo",
  ft = "todo",
  config = function()
    require("neotodo").setup({
      keybinds = {
        add_task = "<leader>ta",
        mark_done = "<leader>td",
        move_task = "<leader>tm",
        navigate_to_section = "<leader>ts",
        focus_mode_enable = "<leader>tf",
        focus_mode_disable = "<leader>tF",
      }
    })
  end,
}
```

### vim-plug

```vim
Plug 'zopu/neotodo'
```

Then in your Lua config or init.vim:

```lua
require("neotodo").setup({
  keybinds = {
    add_task = "<leader>ta",
    mark_done = "<leader>td",
    move_task = "<leader>tm",
    navigate_to_section = "<leader>ts",
    focus_mode_enable = "<leader>tf",
    focus_mode_disable = "<leader>tF",
  }
})
```

## Configuration

The plugin accepts a configuration table in the `setup()` function. All fields are optional.

### Default Configuration

```lua
require("neotodo").setup({
  -- Buffer patterns to match TODO files (default: {"TODO.txt", "todo.txt"})
  file_patterns = { "TODO.txt", "todo.txt" },

  -- Sections visible in focus mode
  focus_sections = { "Now", "Top This Week", "Today" },

  -- Keybindings (set to nil or empty string to disable)
  keybinds = {
    add_task = nil,              -- Add new task to "New" section
    mark_done = nil,             -- Move current task to "Done" section
    move_task = nil,             -- Move current task to another section (opens picker)
    navigate_to_section = nil,   -- Jump to a section (opens picker)
    focus_mode_enable = nil,     -- Hide all sections except focus sections
    focus_mode_disable = nil,    -- Show all sections
  },
})
```

### Picker Integration

NeoTODO uses [Snacks.nvim](https://github.com/folke/snacks.nvim) for the section picker if available, falling back to `vim.ui.select()` otherwise. For the best experience, install Snacks.nvim:

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    picker = { enabled = true },
  },
}
```

## Commands

All commands are available as Ex commands and can be called directly:

- `:NeoTodoAddTask` - Add a new task to the "New" section
- `:NeoTodoMarkAsDone` - Move the current task to the "Done" section
- `:NeoTodoMoveTask` - Move the current task to another section
- `:NeoTodoNavigate` - Navigate to a section
- `:NeoTodoFocusEnable` - Enable focus mode
- `:NeoTodoFocusDisable` - Disable focus mode

## Documentation

For complete documentation, see `:help neotodo` in Neovim after installation.

## Requirements

- Neovim >= 0.9.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for testing only, not required for normal usage)

## License

MIT

