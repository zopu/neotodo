describe("focus", function()
	local focus = require("neotodo.focus")

	it("identifies sections to fold", function()
		assert.is_true(focus.should_fold_section("New"))
		assert.is_true(focus.should_fold_section("Done"))
		assert.is_false(focus.should_fold_section("Now"))
		assert.is_false(focus.should_fold_section("Today"))
		assert.is_false(focus.should_fold_section("Top This Week"))
	end)

	it("enables focus mode", function()
		vim.cmd("enew")
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
		vim.cmd("enew")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"New:",
			"  task",
			"",
			"Now:",
			"  current task",
		})

		-- First enable focus mode
		focus.focus_mode_enable()
		assert.is_true(vim.b.neotodo_focus_mode)

		-- Then disable it
		focus.focus_mode_disable()

		assert.is_false(vim.b.neotodo_focus_mode)
	end)

	it("checks if focus mode is enabled", function()
		vim.cmd("enew")
		assert.is_false(focus.is_focus_mode_enabled())

		vim.b.neotodo_focus_mode = true
		assert.is_true(focus.is_focus_mode_enabled())

		vim.b.neotodo_focus_mode = false
		assert.is_false(focus.is_focus_mode_enabled())
	end)

	it("toggles focus mode", function()
		vim.cmd("enew")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"New:",
			"  task",
			"",
			"Now:",
			"  current task",
		})

		-- Initially disabled
		assert.is_false(focus.is_focus_mode_enabled())

		-- Toggle to enable
		focus.focus_mode_toggle()
		assert.is_true(focus.is_focus_mode_enabled())

		-- Toggle to disable
		focus.focus_mode_toggle()
		assert.is_false(focus.is_focus_mode_enabled())
	end)
end)
