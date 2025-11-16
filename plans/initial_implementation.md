# NeoTODO Initial Implementation Plan

This document outlines the implementation plan for the NeoTODO plugin, broken down into cohesive commits with incremental testing.

## Testing Strategy

We use **plenary.nvim** for lightweight automated testing. Tests are added alongside each feature commit rather than at the end. Each test:
- Creates a scratch buffer with sample TODO.txt content
- Calls the function being tested
- Asserts the buffer state or return values are correct
- Runs in under 100ms

## Commit 1: Initial plugin structure ✓ COMPLETED

**Commit**: `692f2dcf0795031853e75763bd1f06df41991ea8`

**Purpose**: Set up the basic Neovim plugin skeleton.

**Files to create**:
- `plugin/neotodo.vim` - Vim plugin loader
- `lua/neotodo/init.lua` - Main entry point with `setup()` function
- `lua/neotodo/config.lua` - Default configuration

**What it does**:
- Provides a `setup()` function that can be called from user's config
- Stores default configuration (keybinds will be nil/empty by default)
- No functionality yet, just the scaffolding

**Testable**: Can call `require('neotodo').setup()` without errors.

---

## Commit 1a: Testing infrastructure ✓ COMPLETED

**Commit**: `a5c4d20f98d682762505f57f7faba22d9e7290f4`

**Purpose**: Set up minimal test infrastructure for incremental testing.

**Files to create**:
- `tests/minimal_init.lua` - Minimal Neovim config that loads plenary and neotodo
- `tests/init_spec.lua` - Smoke test that plugin loads
- `justfile` - Build commands including `test` recipe

**What it does**:
- Configures test environment with plenary.nvim
- Provides `just test` command to run all tests
- Initial test verifies plugin loads without errors

**Test example** (`tests/init_spec.lua`):
```lua
local neotodo = require('neotodo')

describe("neotodo", function()
  it("can be required", function()
    assert.is_not_nil(neotodo)
  end)

  it("can call setup without errors", function()
    neotodo.setup()
    assert.is_true(true)
  end)
end)
```

**Example justfile**:
```just
# Run all tests
test:
    nvim --headless -c "PlenaryBustedDirectory tests/"

# Run tests on file change (requires watchexec or entr)
test-watch:
    watchexec -e lua just test

# Run a specific test file
test-file FILE:
    nvim --headless -c "PlenaryBustedFile tests/{{FILE}}"

# Run tests with coverage (if luacov installed)
test-coverage:
    nvim --headless -c "PlenaryBustedDirectory tests/"
    luacov
```

**Run tests**: `just test` or `nvim --headless -c "PlenaryBustedDirectory tests/"`

---

## Commit 2: Section parsing utilities ✓ COMPLETED

**Purpose**: Implement core functions to parse TODO.txt file structure.

**Files to create**:
- `lua/neotodo/parser.lua`
- `tests/parser_spec.lua` ⭐

**Functions to implement**:
- `get_sections()` - Returns list of section headers with line numbers
- `get_section_at_line(line_num)` - Returns which section a line belongs to
- `get_section_range(section_name)` - Returns start/end line numbers for a section
- `is_section_header(line)` - Returns true if line is a section header (ends with `:`)
- `is_task_line(line)` - Returns true if line is indented (a task)

**What it does**:
- Parses the current buffer to identify sections and tasks
- Returns structured data about file organization
- Handles edge cases (missing sections, empty sections, etc.)

**Tests to add** (`tests/parser_spec.lua`):
```lua
describe("parser", function()
  local parser = require('neotodo.parser')

  before_each(function()
    -- Create scratch buffer with sample content
    vim.cmd('enew')
    local lines = {
      "New:",
      "  task 1",
      "",
      "Done:",
      "  completed task",
    }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end)

  it("identifies section headers", function()
    assert.is_true(parser.is_section_header("New:"))
    assert.is_true(parser.is_section_header("Done:"))
    assert.is_false(parser.is_section_header("  task"))
  end)

  it("identifies task lines", function()
    assert.is_true(parser.is_task_line("  task 1"))
    assert.is_false(parser.is_task_line("New:"))
  end)

  it("gets all sections with line numbers", function()
    local sections = parser.get_sections()
    assert.equals(2, #sections)
    assert.equals("New", sections[1].name)
    assert.equals(1, sections[1].line)
    assert.equals("Done", sections[2].name)
    assert.equals(4, sections[2].line)
  end)

  it("gets section at specific line", function()
    assert.equals("New", parser.get_section_at_line(2))
    assert.equals("Done", parser.get_section_at_line(5))
  end)

  it("gets section range", function()
    local start_line, end_line = parser.get_section_range("New")
    assert.equals(1, start_line)
    assert.equals(3, end_line)
  end)

  it("handles empty buffer", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    local sections = parser.get_sections()
    assert.equals(0, #sections)
  end)
end)
```

**Testable**: All parser functions work correctly with various buffer contents.

---

## Commit 3: AddTask command

**Purpose**: Implement the simplest command - adding a new task to the "New" section.

**Files to create/modify**:
- `lua/neotodo/commands.lua` - Command implementations
- `lua/neotodo/init.lua` - Register the AddTask command
- `tests/commands_spec.lua` ⭐

**Functions to implement**:
- `add_task()` - Find or create "New:" section, add indented line, enter insert mode

**What it does**:
- Uses parser to find "New:" section
- If "New:" doesn't exist, creates it at the top of file
- Adds a new indented line (e.g., `  `) under "New:"
- Places cursor on new line in insert mode
- Preserves blank line after section if it exists

**Tests to add** (`tests/commands_spec.lua`):
```lua
describe("commands", function()
  local commands = require('neotodo.commands')

  describe("add_task", function()
    it("adds task to existing New section", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  existing task",
        "",
        "Done:",
      })

      commands.add_task()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("New:", lines[1])
      assert.equals("  existing task", lines[2])
      assert.equals("  ", lines[3])  -- New task added
    end)

    it("creates New section if missing", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Done:",
        "  completed task",
      })

      commands.add_task()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("New:", lines[1])
      assert.equals("  ", lines[2])  -- New task
    end)

    it("places cursor on new task line", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"New:"})

      commands.add_task()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, cursor[1])  -- Line 2 (1-indexed)
    end)
  end)
end)
```

**Testable**: Task line is added to New section; cursor positioned correctly.

---

## Commit 4: Task movement utilities

**Purpose**: Create shared utilities for moving tasks between sections.

**Files to create**:
- `lua/neotodo/task_mover.lua`
- `tests/task_mover_spec.lua` ⭐

**Functions to implement**:
- `get_current_task()` - Returns the task text and line number under cursor
- `delete_task_line(line_num)` - Removes a task line from buffer
- `add_task_to_section(section_name, task_text)` - Appends task to a section
- `ensure_section_exists(section_name)` - Creates section if missing

**What it does**:
- Provides reusable functions for task manipulation
- Handles creating sections if they don't exist
- Preserves indentation and formatting

**Tests to add** (`tests/task_mover_spec.lua`):
```lua
describe("task_mover", function()
  local task_mover = require('neotodo.task_mover')

  before_each(function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task to move",
      "",
      "Done:",
    })
  end)

  it("gets current task", function()
    vim.api.nvim_win_set_cursor(0, {2, 0})  -- Line 2

    local task, line = task_mover.get_current_task()
    assert.equals("  task to move", task)
    assert.equals(2, line)
  end)

  it("adds task to section", function()
    task_mover.add_task_to_section("Done", "  completed item")

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.equals("  completed item", lines[5])
  end)

  it("deletes task line", function()
    task_mover.delete_task_line(2)

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.equals(3, #lines)  -- One line removed
    assert.equals("", lines[2])  -- Blank line now at position 2
  end)

  it("ensures section exists", function()
    task_mover.ensure_section_exists("Today")

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    -- Check that "Today:" was added
    local found = false
    for _, line in ipairs(lines) do
      if line == "Today:" then found = true end
    end
    assert.is_true(found)
  end)

  it("does not duplicate existing section", function()
    local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    task_mover.ensure_section_exists("Done")
    local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    assert.equals(#lines_before, #lines_after)
  end)
end)
```

**Testable**: Tasks can be moved programmatically between sections.

---

## Commit 5: MarkAsDone command

**Purpose**: Implement moving a task to the "Done" section.

**Files to modify**:
- `lua/neotodo/commands.lua` - Add `mark_as_done()` function
- `lua/neotodo/init.lua` - Register the MarkAsDone command
- `tests/commands_spec.lua` ⭐ (add tests)

**Functions to implement**:
- `mark_as_done()` - Uses task_mover to move current task to "Done:" section

**What it does**:
- Gets the task under cursor
- Removes it from current section
- Adds it to "Done:" section (creates section if needed)
- Maintains cursor position (moves to next task or stays in section)

**Tests to add** (in `tests/commands_spec.lua`):
```lua
describe("mark_as_done", function()
  it("moves task to Done section", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task to complete",
      "",
      "Done:",
    })
    vim.api.nvim_win_set_cursor(0, {2, 0})

    commands.mark_as_done()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.equals("  task to complete", lines[5])  -- Moved to Done
    assert.equals("", lines[2])  -- Removed from New (blank line remains)
  end)

  it("creates Done section if missing", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task to complete",
    })
    vim.api.nvim_win_set_cursor(0, {2, 0})

    commands.mark_as_done()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local has_done = false
    for _, line in ipairs(lines) do
      if line == "Done:" then has_done = true end
    end
    assert.is_true(has_done)
  end)
end)
```

**Testable**: Task moves to Done section correctly.

---

## Commit 6: MoveTaskToSection command

**Purpose**: Allow moving a task to any section (without picker UI for now).

**Files to modify**:
- `lua/neotodo/commands.lua` - Add `move_task_to_section(section_name)` function
- `lua/neotodo/init.lua` - Register command
- `tests/commands_spec.lua` ⭐ (add tests)

**Functions to implement**:
- `move_task_to_section(section_name)` - Moves current task to specified section

**What it does**:
- Gets current task
- Moves task to specified section
- UI picker will be added in next commit

**Tests to add** (in `tests/commands_spec.lua`):
```lua
describe("move_task_to_section", function()
  it("moves task to specified section", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task to move",
      "",
      "Today:",
    })
    vim.api.nvim_win_set_cursor(0, {2, 0})

    commands.move_task_to_section("Today")

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.equals("  task to move", lines[5])  -- Moved to Today
  end)
end)
```

---

## Commit 7: UI picker and section navigation

**Purpose**: Add UI picker for sections and navigation command.

**Files to create/modify**:
- `lua/neotodo/ui.lua` - UI picker helpers
- `lua/neotodo/commands.lua` - Add `navigate_to_section()` function
- Update `move_task_to_section()` to use picker
- `tests/ui_spec.lua` ⭐ (lightweight tests)

**Functions to implement**:
- `ui.pick_section(sections, callback)` - Shows picker (vim.ui.select)
- `navigate_to_section()` - Opens picker, jumps cursor to selected section

**What it does**:
- Lists all sections in picker
- On selection, moves cursor to that section's header line
- Uses vim.ui.select (can be overridden by user with telescope/fzf)

**Tests to add** (`tests/ui_spec.lua`):
```lua
describe("ui", function()
  local ui = require('neotodo.ui')

  -- Note: UI tests are tricky; test the helper functions
  it("formats section for picker", function()
    local sections = {
      {name = "New", line = 1},
      {name = "Done", line = 10},
    }

    local formatted = ui.format_sections_for_picker(sections)
    assert.equals(2, #formatted)
  end)
end)

describe("navigate_to_section", function()
  it("moves cursor to section header", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task",
      "",
      "Done:",
    })

    -- Directly call navigation (skip picker for testing)
    commands.navigate_to_section_direct("Done")

    local cursor = vim.api.nvim_win_get_cursor(0)
    assert.equals(4, cursor[1])  -- Line 4
  end)
end)
```

---

## Commit 8: Focus mode implementation

**Purpose**: Hide sections except "Now" and "Top This Week".

**Files to create/modify**:
- `lua/neotodo/focus.lua` - Focus mode logic
- `lua/neotodo/commands.lua` - Add `focus_mode_enable()` and `focus_mode_disable()`
- `lua/neotodo/init.lua` - Register focus mode commands
- `tests/focus_spec.lua` ⭐

**Functions to implement**:
- `focus_mode_enable()` - Folds or conceals non-focused sections
- `focus_mode_disable()` - Shows all sections
- `is_focus_mode_enabled()` - Returns current state
- `should_fold_section(section_name)` - Returns true if section should be hidden

**Implementation approach**:
- Use Neovim's folding with `foldmethod=expr` and `foldexpr`
- Fold all sections except "Now:" and "Top This Week:"
- Store state in buffer variable `b:neotodo_focus_mode`

**Tests to add** (`tests/focus_spec.lua`):
```lua
describe("focus", function()
  local focus = require('neotodo.focus')

  it("identifies sections to fold", function()
    assert.is_true(focus.should_fold_section("New"))
    assert.is_true(focus.should_fold_section("Done"))
    assert.is_false(focus.should_fold_section("Now"))
    assert.is_false(focus.should_fold_section("Top This Week"))
  end)

  it("enables focus mode", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "New:",
      "  task",
      "",
      "Now:",
      "  current task",
    })

    focus.focus_mode_enable()

    assert.is_true(vim.b.neotodo_focus_mode)
    -- Check fold settings were applied
    assert.equals("expr", vim.wo.foldmethod)
  end)

  it("disables focus mode", function()
    vim.b.neotodo_focus_mode = true
    focus.focus_mode_disable()

    assert.is_false(vim.b.neotodo_focus_mode)
  end)
end)
```

**Testable**: Focus mode state changes correctly; fold settings applied.

---

## Commit 9: Buffer-local keybindings

**Purpose**: Set up keybindings that only work in TODO.txt files.

**Files to create/modify**:
- `ftdetect/todo.vim` - Detect TODO.txt files
- `lua/neotodo/config.lua` - Add default keybinding config
- `lua/neotodo/keybinds.lua` - Keybinding setup logic
- `lua/neotodo/init.lua` - Update setup() to accept keybind config
- `tests/keybinds_spec.lua` ⭐

**What it does**:
- Detects buffers named `TODO.txt` or with custom pattern
- Applies buffer-local keybindings based on user config

**Tests to add** (`tests/keybinds_spec.lua`):
```lua
describe("keybinds", function()
  local keybinds = require('neotodo.keybinds')

  it("sets up buffer-local keybindings", function()
    vim.cmd('enew')
    vim.cmd('file TODO.txt')

    local config = {
      keybinds = {
        add_task = '<leader>ta',
        mark_done = '<leader>td',
      }
    }

    keybinds.setup_buffer_keybinds(config)

    -- Check that keymaps exist for this buffer
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local has_ta = false
    for _, map in ipairs(maps) do
      if map.lhs == '<leader>ta' then has_ta = true end
    end
    assert.is_true(has_ta)
  end)

  it("does not set keybinds in non-TODO buffers", function()
    vim.cmd('enew')
    vim.cmd('file other.txt')

    -- Should not apply keybinds
    local maps = vim.api.nvim_buf_get_keymap(0, 'n')
    local count_before = #maps

    keybinds.setup_buffer_keybinds({keybinds = {add_task = '<leader>ta'}})

    maps = vim.api.nvim_buf_get_keymap(0, 'n')
    -- If applied correctly, keybinds shouldn't be added
    -- (This test assumes keybinds.lua checks buffer name)
  end)
end)
```

---

## Commit 10: Autocommands and buffer setup

**Purpose**: Automatically initialize buffers when opening TODO.txt files.

**Files to create/modify**:
- `lua/neotodo/autocmds.lua` - Autocommand setup
- `lua/neotodo/init.lua` - Set up autocommands in setup()
- `tests/autocmds_spec.lua` ⭐

**What it does**:
- Creates autocommand group for neotodo
- On opening TODO.txt buffer: applies keybindings and settings
- On leaving buffer: cleans up state if needed

**Tests to add** (`tests/autocmds_spec.lua`):
```lua
describe("autocmds", function()
  local autocmds = require('neotodo.autocmds')

  it("creates autocommand group", function()
    autocmds.setup()

    local groups = vim.api.nvim_get_autocmds({group = "NeoTodo"})
    assert.is_true(#groups > 0)
  end)

  it("triggers on TODO.txt buffer open", function()
    autocmds.setup()

    vim.cmd('enew')
    vim.cmd('file TODO.txt')
    vim.cmd('doautocmd BufEnter')

    -- Check that setup was triggered (e.g., buffer var set)
    -- This depends on implementation details
  end)
end)
```

---

## Commit 11: Documentation

**Purpose**: Add Vim help documentation.

**Files to create**:
- `doc/neotodo.txt` - Vim help file
- `doc/tags` - Help tags (auto-generated)

**No automated tests** - Documentation quality is verified manually.

---

## Commit 12: CI and test automation

**Purpose**: Set up GitHub Actions for automated testing.

**Files to create**:
- `.github/workflows/test.yml` - CI workflow

**What it does**:
- Runs all tests on every push/PR
- Tests against multiple Neovim versions (stable, nightly)
- Reports test failures

**Example workflow**:
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
      - uses: extractions/setup-just@v1
      - name: Install plenary
        run: |
          git clone https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/plenary/start/plenary.nvim
      - name: Run tests
        run: just test
```

---

## Commit 13: README updates and examples

**Purpose**: Update README with installation and usage instructions.

**Files to modify**:
- `README.md`

**Additions**:
- Installation instructions (lazy.nvim, packer, etc.)
- Setup example with configuration
- Link to help documentation
- Badge showing CI status

---

## Running Tests

### Local development
```bash
just test                 # Run all tests
just test-watch          # Run tests on file change (if implemented)
```

### Individual test files
```bash
nvim --headless -c "PlenaryBustedFile tests/parser_spec.lua"
```

### With coverage (optional future enhancement)
```bash
just test-coverage
```

---

## Notes

### Test Dependencies
- **Required**: plenary.nvim (test framework)
- **Optional**: luacov (code coverage)

### Test Conventions
- Test files named `*_spec.lua`
- Use `describe()` for grouping, `it()` for individual tests
- Use `before_each()` to set up clean buffer state
- Keep tests fast (<100ms each) and isolated

### What NOT to test
- UI interactions with fzf/telescope (mock these)
- Insert mode behavior (test the state change, not the UI)
- External plugin integrations

### Future Testing Enhancements
- Add luacov for code coverage reporting
- Integration tests with real TODO.txt files
- Performance benchmarks for large files (1000+ tasks)
