-- Test suite for command implementations

local commands = require("neotodo.commands")

describe("commands", function()
	describe("add_task", function()
		it("adds task to existing New section", function()
			vim.cmd("enew")
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
			assert.equals("  ", lines[3]) -- New task added
		end)

		it("creates New section if missing", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"Done:",
				"  completed task",
			})

			commands.add_task()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("New:", lines[1])
			assert.equals("  ", lines[2]) -- New task
			assert.equals("", lines[3]) -- Blank line separator
			assert.equals("Done:", lines[4])
		end)

		it("places cursor on new task line", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "New:" })

			commands.add_task()

			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(2, cursor[1]) -- Line 2 (1-indexed)
		end)

		it("handles empty buffer", function()
			vim.cmd("enew")
			-- Empty buffer

			commands.add_task()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("New:", lines[1])
			assert.equals("  ", lines[2])
			-- No blank line after when buffer was empty
			assert.equals(2, #lines)
		end)

		it("adds task after multiple existing tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"  second task",
				"",
				"Done:",
			})

			commands.add_task()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("New:", lines[1])
			assert.equals("  first task", lines[2])
			assert.equals("  second task", lines[3])
			assert.equals("  ", lines[4]) -- New task added after existing tasks
		end)

		it("preserves blank line after New section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  existing task",
				"",
				"Today:",
			})

			commands.add_task()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  ", lines[3]) -- New task
			assert.equals("", lines[4]) -- Blank line preserved
			assert.equals("Today:", lines[5])
		end)
	end)

	describe("mark_as_done", function()
		it("moves task to Done section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to complete",
				"",
				"Done:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.mark_as_done()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Task should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Task removed, blank line remains
			assert.equals("Done:", lines[3])
			assert.equals("  task to complete", lines[4]) -- Moved to Done
		end)

		it("creates Done section if missing", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to complete",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.mark_as_done()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_done = false
			local done_line = 0
			for i, line in ipairs(lines) do
				if line == "Done:" then
					has_done = true
					done_line = i
				end
			end
			assert.is_true(has_done)
			-- Verify task was added to Done section
			assert.equals("  task to complete", lines[done_line + 1])
		end)

		it("handles cursor positioning after deletion", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to complete",
				"  next task",
				"",
				"Done:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.mark_as_done()

			-- Cursor should move to the next task
			local cursor = vim.api.nvim_win_get_cursor(0)
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  next task", lines[cursor[1]])
		end)

		it("does nothing when cursor is not on a task", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
				"",
				"Done:",
			})
			vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- On section header

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.mark_as_done()
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)
	end)

	describe("mark_as_done_visual", function()
		it("moves multiple selected tasks to Done section", function()
			vim.cmd("enew")
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

			commands.mark_as_done_visual()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Tasks should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Blank line remains
			assert.equals("Done:", lines[3])
			-- All tasks moved to Done
			assert.equals("  task 1", lines[4])
			assert.equals("  task 2", lines[5])
			assert.equals("  task 3", lines[6])
		end)

		it("creates Done section if missing", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
			})

			-- Set visual selection marks
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

			commands.mark_as_done_visual()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_done = false
			local done_line = 0
			for i, line in ipairs(lines) do
				if line == "Done:" then
					has_done = true
					done_line = i
				end
			end
			assert.is_true(has_done)
			-- Verify tasks were added to Done section
			assert.equals("  task 1", lines[done_line + 1])
			assert.equals("  task 2", lines[done_line + 2])
		end)
	end)

	describe("move_to_now_visual", function()
		it("moves multiple selected tasks to Now section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
				"  task 3",
				"",
				"Now:",
			})

			-- Set visual selection marks for lines 2-4
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

			commands.move_to_now_visual()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Tasks should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Blank line remains
			assert.equals("Now:", lines[3])
			-- All tasks moved to Now
			assert.equals("  task 1", lines[4])
			assert.equals("  task 2", lines[5])
			assert.equals("  task 3", lines[6])
		end)

		it("creates Now section if missing", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
			})

			-- Set visual selection marks
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

			commands.move_to_now_visual()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_now = false
			local now_line = 0
			for i, line in ipairs(lines) do
				if line == "Now:" then
					has_now = true
					now_line = i
				end
			end
			assert.is_true(has_now)
			-- Verify tasks were added to Now section
			assert.equals("  task 1", lines[now_line + 1])
			assert.equals("  task 2", lines[now_line + 2])
		end)

		it("does nothing when selection spans multiple sections", function()
			vim.cmd("enew")
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

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.move_to_now_visual()
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)
	end)

	describe("move_to_now", function()
		it("moves task to Now section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to move",
				"",
				"Now:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_to_now()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Task should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Task removed, blank line remains
			assert.equals("Now:", lines[3])
			assert.equals("  task to move", lines[4]) -- Moved to Now
		end)

		it("creates Now section if missing", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to move",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_to_now()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_now = false
			local now_line = 0
			for i, line in ipairs(lines) do
				if line == "Now:" then
					has_now = true
					now_line = i
				end
			end
			assert.is_true(has_now)
			-- Verify task was added to Now section
			assert.equals("  task to move", lines[now_line + 1])
		end)

		it("handles cursor positioning after moving task", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to move",
				"  next task",
				"",
				"Now:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_to_now()

			-- Cursor should move to the next task
			local cursor = vim.api.nvim_win_get_cursor(0)
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  next task", lines[cursor[1]])
		end)

		it("does nothing when cursor is not on a task", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
				"",
				"Now:",
			})
			vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- On section header

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.move_to_now()
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)

		it("handles moving from multiple tasks in a section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"  second task to move",
				"  third task",
				"",
				"Now:",
			})
			vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- On second task

			commands.move_to_now()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  first task", lines[2])
			assert.equals("  third task", lines[3])
			assert.equals("Now:", lines[5])
			assert.equals("  second task to move", lines[6])
		end)

		it("moves task from Done section to Now", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"Done:",
				"  completed task to reactivate",
				"",
				"Now:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_to_now()

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Task should be removed from Done section
			assert.equals("Done:", lines[1])
			assert.equals("", lines[2])
			assert.equals("Now:", lines[3])
			assert.equals("  completed task to reactivate", lines[4])
		end)
	end)

	describe("navigate_to_section", function()
		-- Helper to mock ui.pick_section
		local function mock_pick_section_and_call(section_name, section_line)
			local ui = require("neotodo.ui")
			local original_pick_section = ui.pick_section

			-- Mock pick_section to immediately invoke callback
			ui.pick_section = function(sections, callback, bufnr, prompt)
				callback(section_name, section_line)
			end

			-- Restore original after test
			return function()
				ui.pick_section = original_pick_section
			end
		end

		it("positions cursor on first task when section has tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"  second task",
				"",
				"Today:",
				"  today task",
				"",
				"Done:",
			})

			-- Mock pick_section to select "Today" section (line 5)
			local restore = mock_pick_section_and_call("Today", 5)

			commands.navigate_to_section()

			-- Cursor should be on the first task in Today section (line 6)
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(6, cursor[1])

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  today task", lines[cursor[1]])

			-- Cursor should be at end of line
			assert.equals(#"  today task", cursor[2])

			restore()
		end)

		it("positions cursor on section header when section is empty", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"",
				"Today:",
				"",
				"Done:",
			})

			-- Mock pick_section to select "Today" section (line 4)
			local restore = mock_pick_section_and_call("Today", 4)

			commands.navigate_to_section()

			-- Cursor should be on the section header (line 4) since section is empty
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(4, cursor[1])

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("Today:", lines[cursor[1]])

			-- Cursor should be at end of line
			assert.equals(#"Today:", cursor[2])

			restore()
		end)

		it("positions cursor on first task when section has blank lines before tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"",
				"Today:",
				"",
				"  today task after blank",
				"",
				"Done:",
			})

			-- Mock pick_section to select "Today" section (line 4)
			local restore = mock_pick_section_and_call("Today", 4)

			commands.navigate_to_section()

			-- Cursor should be on the first task (line 6), skipping blank line
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(6, cursor[1])

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  today task after blank", lines[cursor[1]])

			-- Cursor should be at end of line
			assert.equals(#"  today task after blank", cursor[2])

			restore()
		end)

		it("positions cursor on first task in section with multiple tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  new task 1",
				"  new task 2",
				"  new task 3",
				"",
				"Done:",
			})

			-- Mock pick_section to select "New" section (line 1)
			local restore = mock_pick_section_and_call("New", 1)

			commands.navigate_to_section()

			-- Cursor should be on the first task (line 2)
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(2, cursor[1])

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  new task 1", lines[cursor[1]])

			-- Cursor should be at end of line
			assert.equals(#"  new task 1", cursor[2])

			restore()
		end)
	end)

	describe("move_task_to_section", function()
		it("moves task to specified section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to move",
				"",
				"Today:",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_task_to_section("Today")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Task should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Task removed
			assert.equals("Today:", lines[3])
			assert.equals("  task to move", lines[4]) -- Moved to Today
		end)

		it("creates target section if it doesn't exist", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task to move",
			})
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			commands.move_task_to_section("Today")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_today = false
			local today_line = 0
			for i, line in ipairs(lines) do
				if line == "Today:" then
					has_today = true
					today_line = i
				end
			end
			assert.is_true(has_today)
			-- Verify task was added to Today section
			assert.equals("  task to move", lines[today_line + 1])
		end)

		it("does nothing when cursor is not on a task", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
				"",
				"Today:",
			})
			vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- On section header

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.move_task_to_section("Today")
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)

		it("handles multiple tasks and moves only the current one", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first task",
				"  second task to move",
				"  third task",
				"",
				"Today:",
			})
			vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- On second task

			commands.move_task_to_section("Today")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.equals("  first task", lines[2])
			assert.equals("  third task", lines[3])
			assert.equals("Today:", lines[5])
			assert.equals("  second task to move", lines[6])
		end)
	end)

	describe("move_tasks_to_section_visual", function()
		it("moves multiple selected tasks to specified section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
				"  task 3",
				"",
				"Today:",
			})

			-- Set visual selection marks for lines 2-4
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

			commands.move_tasks_to_section_visual("Today")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Tasks should be removed from New section
			assert.equals("New:", lines[1])
			assert.equals("", lines[2]) -- Blank line remains
			assert.equals("Today:", lines[3])
			-- All tasks moved to Today
			assert.equals("  task 1", lines[4])
			assert.equals("  task 2", lines[5])
			assert.equals("  task 3", lines[6])
		end)

		it("preserves task order when moving multiple tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  first",
				"  second",
				"  third",
				"",
				"Done:",
			})

			-- Set visual selection marks for all three tasks
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

			commands.move_tasks_to_section_visual("Done")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Verify order is preserved
			assert.equals("  first", lines[4])
			assert.equals("  second", lines[5])
			assert.equals("  third", lines[6])
		end)

		it("creates target section if it doesn't exist", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
			})

			-- Set visual selection marks
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

			commands.move_tasks_to_section_visual("Today")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local has_today = false
			local today_line = 0
			for i, line in ipairs(lines) do
				if line == "Today:" then
					has_today = true
					today_line = i
				end
			end
			assert.is_true(has_today)
			-- Verify tasks were added to Today section
			assert.equals("  task 1", lines[today_line + 1])
			assert.equals("  task 2", lines[today_line + 2])
		end)

		it("does nothing when selection contains no tasks", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"",
				"",
				"Today:",
			})

			-- Set visual selection marks on blank lines
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.move_tasks_to_section_visual("Today")
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)

		it("does nothing when selection spans multiple sections", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"",
				"Today:",
				"  task 2",
			})

			-- Set visual selection marks spanning both sections
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 5, 0, {})

			local lines_before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			commands.move_tasks_to_section_visual("Done")
			local lines_after = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- Buffer should be unchanged
			assert.same(lines_before, lines_after)
		end)

		it("ignores non-task lines in selection", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"",
				"  task 2",
				"",
				"Done:",
			})

			-- Set visual selection marks including blank line
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 4, 0, {})

			commands.move_tasks_to_section_visual("Done")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Only the two tasks should be moved
			-- Blank lines remain: New:, "", "", Done:, task 1, task 2
			assert.equals("New:", lines[1])
			assert.equals("", lines[2])
			assert.equals("", lines[3])
			assert.equals("Done:", lines[4])
			assert.equals("  task 1", lines[5])
			assert.equals("  task 2", lines[6])
		end)

		it("appends tasks to existing tasks in target section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  new task 1",
				"  new task 2",
				"",
				"Done:",
				"  existing done task",
			})

			-- Set visual selection marks for new tasks
			vim.api.nvim_buf_set_mark(0, '<', 2, 0, {})
			vim.api.nvim_buf_set_mark(0, '>', 3, 0, {})

			commands.move_tasks_to_section_visual("Done")

			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- Tasks should be appended after existing task
			assert.equals("Done:", lines[3])
			assert.equals("  existing done task", lines[4])
			assert.equals("  new task 1", lines[5])
			assert.equals("  new task 2", lines[6])
		end)
	end)
end)
