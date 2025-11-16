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
end)
