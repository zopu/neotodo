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
		local original_bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"New:",
			"  task",
			"",
			"Now:",
			"  current task",
		})

		focus.focus_mode_enable()

		-- Should have switched to a new focus buffer
		local focus_bufnr = vim.api.nvim_get_current_buf()
		assert.are_not.equal(original_bufnr, focus_bufnr)

		-- Focus buffer should have focus mode enabled
		assert.is_true(vim.b.neotodo_focus_mode)

		-- Focus buffer should be a scratch buffer
		assert.equals("nofile", vim.bo.buftype)

		-- Focus buffer should only contain visible sections (Now:)
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		-- Should not contain "New:" section, only "Now:" section
		assert.is_true(#lines > 0)
		local has_now = false
		local has_new = false
		for _, line in ipairs(lines) do
			if line:match("^Now:") then has_now = true end
			if line:match("^New:") then has_new = true end
		end
		assert.is_true(has_now)
		assert.is_false(has_new)
	end)

	it("disables focus mode", function()
		vim.cmd("enew")
		local original_bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"New:",
			"  task",
			"",
			"Now:",
			"  current task",
		})

		-- First enable focus mode
		focus.focus_mode_enable()
		local focus_bufnr = vim.api.nvim_get_current_buf()
		assert.is_true(vim.b.neotodo_focus_mode)
		assert.are_not.equal(original_bufnr, focus_bufnr)

		-- Then disable it
		focus.focus_mode_disable()

		-- Should have switched back to original buffer
		local current_bufnr = vim.api.nvim_get_current_buf()
		assert.equals(original_bufnr, current_bufnr)

		-- Focus buffer should no longer exist (auto-deleted)
		assert.is_false(vim.api.nvim_buf_is_valid(focus_bufnr))
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
		local original_bufnr = vim.api.nvim_get_current_buf()
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
		local focus_bufnr = vim.api.nvim_get_current_buf()
		assert.are_not.equal(original_bufnr, focus_bufnr)

		-- Toggle to disable
		focus.focus_mode_toggle()
		-- Should be back on original buffer
		assert.equals(original_bufnr, vim.api.nvim_get_current_buf())
		-- Focus buffer should be deleted
		assert.is_false(vim.api.nvim_buf_is_valid(focus_bufnr))
	end)
end)
