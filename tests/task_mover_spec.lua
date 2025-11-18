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

  describe("get_visual_selection_tasks", function()
    it("gets all tasks in visual selection from same section", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "  task 2",
        "  task 3",
        "",
        "Done:",
      })

      -- Set visual selection marks for lines 2-4
      vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
      vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

      local tasks = task_mover.get_visual_selection_tasks()
      assert.is_not_nil(tasks)
      assert.equals(3, #tasks)
      assert.equals("  task 1", tasks[1].text)
      assert.equals(2, tasks[1].line)
      assert.equals("  task 3", tasks[3].text)
      assert.equals(4, tasks[3].line)
    end)

    it("returns nil when selection spans multiple sections", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "",
        "Done:",
        "  task 2",
      })

      -- Set visual selection marks spanning both sections
      vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
      vim.api.nvim_buf_set_mark(0, '>', 5, 0, {})

      local tasks = task_mover.get_visual_selection_tasks()
      assert.is_nil(tasks)
    end)

    it("returns nil when selection contains no tasks", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "",
        "",
        "Done:",
      })

      -- Set visual selection marks on blank lines
      vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
      vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

      local tasks = task_mover.get_visual_selection_tasks()
      assert.is_nil(tasks)
    end)

    it("ignores non-task lines in selection", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "",
        "  task 2",
        "",
        "Done:",
      })

      -- Set visual selection marks including blank lines
      vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
      vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

      local tasks = task_mover.get_visual_selection_tasks()
      assert.is_not_nil(tasks)
      assert.equals(2, #tasks)
      assert.equals("  task 1", tasks[1].text)
      assert.equals("  task 2", tasks[2].text)
    end)
  end)

  describe("delete_task_lines", function()
    it("deletes multiple task lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "  task 2",
        "  task 3",
        "",
        "Done:",
      })

      task_mover.delete_task_lines({2, 3, 4})

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #lines)  -- Three lines removed
      assert.equals("New:", lines[1])
      assert.equals("", lines[2])
      assert.equals("Done:", lines[3])
    end)

    it("handles non-consecutive line deletions", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "  task 2",
        "  task 3",
        "  task 4",
        "",
        "Done:",
      })

      task_mover.delete_task_lines({2, 4})

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(5, #lines)  -- Two lines removed
      assert.equals("  task 2", lines[2])
      assert.equals("  task 4", lines[3])
    end)
  end)

  describe("add_tasks_to_section", function()
    it("adds multiple tasks to section at once", function()
      task_mover.add_tasks_to_section("Done", {"  task 1", "  task 2", "  task 3"})

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("  task 1", lines[5])
      assert.equals("  task 2", lines[6])
      assert.equals("  task 3", lines[7])
    end)

    it("adds tasks after existing tasks in section", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  existing task",
        "",
        "Done:",
      })

      task_mover.add_tasks_to_section("New", {"  new task 1", "  new task 2"})

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("  existing task", lines[2])
      assert.equals("  new task 1", lines[3])
      assert.equals("  new task 2", lines[4])
    end)

    it("handles empty task array", function()
      local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      task_mover.add_tasks_to_section("Done", {})
      local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      assert.equals(#lines_before, #lines_after)
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
