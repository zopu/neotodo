-- task_mover_spec.lua: Tests for task movement utilities

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

  describe("get_current_task", function()
    it("gets current task when cursor is on task line", function()
      vim.api.nvim_win_set_cursor(0, {2, 0})  -- Line 2

      local task, line = task_mover.get_current_task()
      assert.equals("  task to move", task)
      assert.equals(2, line)
    end)

    it("returns nil when cursor is on section header", function()
      vim.api.nvim_win_set_cursor(0, {1, 0})  -- Line 1 (section header)

      local task, line = task_mover.get_current_task()
      assert.is_nil(task)
      assert.is_nil(line)
    end)

    it("returns nil when cursor is on blank line", function()
      vim.api.nvim_win_set_cursor(0, {3, 0})  -- Line 3 (blank)

      local task, line = task_mover.get_current_task()
      assert.is_nil(task)
      assert.is_nil(line)
    end)
  end)

  describe("delete_task_line", function()
    it("deletes specified task line", function()
      task_mover.delete_task_line(2)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #lines)  -- One line removed
      assert.equals("", lines[2])  -- Blank line now at position 2
    end)

    it("handles deleting first task", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  first task",
        "  second task",
      })

      task_mover.delete_task_line(2)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(2, #lines)
      assert.equals("  second task", lines[2])
    end)

    it("handles deleting last line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  only task",
      })

      task_mover.delete_task_line(2)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("New:", lines[1])
    end)
  end)

  describe("add_task_to_section", function()
    it("adds task to existing section", function()
      task_mover.add_task_to_section("Done", "  completed item")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("  completed item", lines[5])
    end)

    it("adds task after existing tasks in section", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  existing task 1",
        "  existing task 2",
        "",
        "Done:",
      })

      task_mover.add_task_to_section("New", "  new task")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("  new task", lines[4])
      assert.equals("", lines[5])  -- Blank line preserved
    end)

    it("adds task to empty section", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "",
        "Done:",
      })

      task_mover.add_task_to_section("New", "  first task")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("  first task", lines[2])
    end)

    it("preserves indentation of task text", function()
      task_mover.add_task_to_section("Done", "    deeply indented task")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("    deeply indented task", lines[5])
    end)
  end)

  describe("ensure_section_exists", function()
    it("creates section when it doesn't exist", function()
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

    it("adds section at end of file", function()
      task_mover.ensure_section_exists("Today")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should be at the end
      assert.equals("Today:", lines[#lines])
    end)

    it("adds blank line before new section if needed", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task",
      })

      task_mover.ensure_section_exists("Done")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("", lines[3])  -- Blank line added
      assert.equals("Done:", lines[4])
    end)

    it("does not add extra blank line if last line is already blank", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task",
        "",
      })

      task_mover.ensure_section_exists("Done")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Done:", lines[4])
      -- Should not have double blank lines
      local blank_count = 0
      for i = 1, #lines - 1 do
        if lines[i] == "" and lines[i+1] == "" then
          blank_count = blank_count + 1
        end
      end
      assert.equals(0, blank_count)
    end)
  end)

  describe("integration scenarios", function()
    it("can move a task from one section to another", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task to move",
        "",
        "Done:",
      })
      vim.api.nvim_win_set_cursor(0, {2, 0})

      -- Simulate moving a task
      local task, line = task_mover.get_current_task()
      assert.is_not_nil(task)

      task_mover.add_task_to_section("Done", task)
      task_mover.delete_task_line(line)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Task should be in Done section (line 4 after deletion shifted lines up)
      assert.equals("  task to move", lines[4])
      -- New section should be empty or have blank line
      assert.not_equals("  task to move", lines[2])
    end)

    it("can add multiple tasks to a new section", function()
      task_mover.ensure_section_exists("Today")
      task_mover.add_task_to_section("Today", "  task 1")
      task_mover.add_task_to_section("Today", "  task 2")
      task_mover.add_task_to_section("Today", "  task 3")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Find the Today section and verify tasks
      local in_today = false
      local task_count = 0
      for _, line in ipairs(lines) do
        if line == "Today:" then
          in_today = true
        elseif in_today and line:match("^%s+task") then
          task_count = task_count + 1
        end
      end
      assert.equals(3, task_count)
    end)
  end)
end)
