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
end)
