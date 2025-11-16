# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NeoTODO is a Neovim plugin for managing TODO.txt files using an opinionated structure with section headers and indented task lists.

## Core Concepts

### TODO.txt File Structure

- Section headers end with a colon (e.g., `New:`, `Today:`, `Done:`)
- Tasks are indented under their section headers
- Required sections with special behavior:
  - **New**: Default location for new tasks
  - **Now**: Tasks in active development
  - **Top This Week**: Remains visible in focus mode
  - **Done**: Completed tasks archive

### Key Features to Implement

1. **Task Management**: Moving tasks between sections, marking as done, adding new tasks
2. **Section Navigation**: Quick jumping between sections (likely using fzf or telescope)
3. **Focus Mode**: Hide/show sections (keeping only "Now" and "Top This Week" visible)
4. **File-Specific Keybinds**: Commands active only when editing TODO.txt files

## Expected Plugin Architecture

Neovim plugins typically use this structure:

```
lua/
  neotodo/
    init.lua          -- Main entry point, setup() function
    commands.lua      -- Command definitions (MoveToSection, MarkAsDone, etc.)
    config.lua        -- Configuration and defaults
    ui.lua            -- UI helpers (focus mode, section folding)
    utils.lua         -- Utility functions (parsing, section manipulation)
plugin/
  neotodo.vim         -- Vim plugin loader (calls lua setup)
```

## Development Commands

### Testing

Neovim plugins are typically tested with:
- `nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim'}"` (using plenary.nvim test framework)
- Manual testing: `nvim -u NONE -c "set rtp+=." -c "lua require('neotodo').setup()" TODO.txt`

### Linting

- Lua: `luacheck lua/` or `selene lua/`
- Formatting: `stylua lua/`

## Implementation Notes

### Keybind Setup

Keybinds should be:
- Configurable in the `setup()` function
- Only active in buffers named `TODO.txt` (use `autocmd FileType` or buffer-local mappings)
- Example: `vim.keymap.set('n', '<leader>td', require('neotodo').mark_done, { buffer = bufnr })`

### Section Parsing

The plugin needs to:
- Identify section headers (lines ending with `:`)
- Track indented tasks under each section
- Preserve formatting and blank lines when moving tasks

### Focus Mode Implementation

Should use Neovim's folding mechanisms or concealment to hide non-focused sections while keeping "Now" and "Top This Week" visible.
