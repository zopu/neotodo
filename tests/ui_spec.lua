-- tests/ui_spec.lua - Tests for UI helpers

describe("ui", function()
	local ui = require("neotodo.ui")
	local commands = require("neotodo.commands")

	describe("format_sections_for_picker", function()
		it("formats sections with line numbers", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"",
				"Done:",
				"  completed task",
			})

			local sections = {
				{ name = "New", line = 1 },
				{ name = "Done", line = 4 },
			}

			local formatted = ui.format_sections_for_picker(sections, 0)
			assert.equals(2, #formatted)
			assert.equals("New", formatted[1].name)
			assert.equals(1, formatted[1].line)
			-- text field is used for searching and contains section name + line
			assert.is_not_nil(formatted[1].text:match("New"))
			assert.equals("Done", formatted[2].name)
			assert.equals(4, formatted[2].line)
			assert.is_not_nil(formatted[2].text:match("Done"))
		end)

		it("handles empty sections array", function()
			vim.cmd("enew")
			local formatted = ui.format_sections_for_picker({}, 0)
			assert.equals(0, #formatted)
		end)

		it("formats sections with complex names", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"Top This Week:",
				"  important task",
				"",
				"Now:",
				"  current task",
			})

			local sections = {
				{ name = "Top This Week", line = 1 },
				{ name = "Now", line = 4 },
			}

			local formatted = ui.format_sections_for_picker(sections, 0)
			assert.equals(2, #formatted)
			assert.equals("Top This Week", formatted[1].name)
			assert.equals(1, formatted[1].line)
			assert.equals("Now", formatted[2].name)
			assert.equals(4, formatted[2].line)
		end)

		it("includes padding for alignment", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
				"",
				"Done:",
			})

			local sections = {
				{ name = "New", line = 1 },
				{ name = "Done", line = 4 },
			}

			local formatted = ui.format_sections_for_picker(sections, 0)
			-- Both items should have the same padding value
			assert.equals(formatted[1].padding, formatted[2].padding)
			-- Padding should be at least max name length + 2
			assert.is_true(formatted[1].padding >= 4) -- "Done" is 4 chars + 2
		end)

		it("includes preview content for sections", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"  task 2",
				"",
				"Done:",
				"  completed task",
			})

			local sections = {
				{ name = "New", line = 1 },
				{ name = "Done", line = 5 },
			}

			local formatted = ui.format_sections_for_picker(sections, 0)
			-- Check that preview field exists
			assert.is_not_nil(formatted[1].preview)
			assert.is_not_nil(formatted[1].preview.text)
			-- Preview should contain task content
			assert.is_not_nil(formatted[1].preview.text:match("task 1"))
			assert.is_not_nil(formatted[1].preview.text:match("task 2"))
		end)

		it("shows message for empty sections", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"",
				"Done:",
			})

			local sections = {
				{ name = "New", line = 1 },
			}

			local formatted = ui.format_sections_for_picker(sections, 0)
			-- Empty section should have a message
			assert.is_not_nil(formatted[1].preview)
			assert.equals("No tasks in this section", formatted[1].preview.text)
		end)
	end)

	describe("navigate_to_section_direct", function()
		it("moves cursor to section header", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
				"",
				"Done:",
			})

			-- Directly call navigation (skip picker for testing)
			ui.navigate_to_section_direct("Done")

			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(4, cursor[1]) -- Line 4
		end)

		it("navigates to first section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"",
				"Today:",
				"  task 2",
				"",
				"Done:",
			})

			ui.navigate_to_section_direct("New")

			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(1, cursor[1]) -- Line 1
		end)

		it("navigates to middle section", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task 1",
				"",
				"Today:",
				"  task 2",
				"",
				"Done:",
			})

			ui.navigate_to_section_direct("Today")

			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(4, cursor[1]) -- Line 4
		end)

		it("handles non-existent section gracefully", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"New:",
				"  task",
			})

			-- Should not error, just notify
			ui.navigate_to_section_direct("NonExistent")

			-- Cursor should remain at original position
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.is_not_nil(cursor)
		end)
	end)

	describe("navigate_to_section command", function()
		it("handles empty buffer gracefully", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

			-- Should notify about no sections
			commands.navigate_to_section()

			-- Should not crash
			assert.is_true(true)
		end)

		it("handles buffer with no sections", function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"just some text",
				"no sections here",
			})

			-- Should notify about no sections
			commands.navigate_to_section()

			-- Should not crash
			assert.is_true(true)
		end)
	end)
end)
