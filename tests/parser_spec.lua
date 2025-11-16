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

  describe("is_section_header", function()
    it("identifies section headers", function()
      assert.is_true(parser.is_section_header("New:"))
      assert.is_true(parser.is_section_header("Done:"))
      assert.is_false(parser.is_section_header("  task"))
    end)

    it("handles section headers with trailing whitespace", function()
      assert.is_true(parser.is_section_header("New:   "))
      assert.is_true(parser.is_section_header("Today:  "))
    end)

    it("handles empty lines", function()
      assert.is_false(parser.is_section_header(""))
      assert.is_false(parser.is_section_header(nil))
    end)

    it("handles lines with colons in the middle", function()
      assert.is_false(parser.is_section_header("  task: something"))
      assert.is_false(parser.is_section_header("not: a: header"))
    end)
  end)

  describe("is_task_line", function()
    it("identifies task lines", function()
      assert.is_true(parser.is_task_line("  task 1"))
      assert.is_false(parser.is_task_line("New:"))
    end)

    it("handles various indentation", function()
      assert.is_true(parser.is_task_line("  task"))
      assert.is_true(parser.is_task_line("    task"))
      assert.is_true(parser.is_task_line("\ttask"))
    end)

    it("handles empty lines", function()
      assert.is_false(parser.is_task_line(""))
      assert.is_false(parser.is_task_line(nil))
    end)

    it("handles non-indented lines", function()
      assert.is_false(parser.is_task_line("New:"))
      assert.is_false(parser.is_task_line("not indented"))
    end)
  end)

  describe("get_sections", function()
    it("gets all sections with line numbers", function()
      local sections = parser.get_sections()
      assert.equals(2, #sections)
      assert.equals("New", sections[1].name)
      assert.equals(1, sections[1].line)
      assert.equals("Done", sections[2].name)
      assert.equals(4, sections[2].line)
    end)

    it("handles buffer with many sections", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "",
        "Today:",
        "  task 2",
        "",
        "Top This Week:",
        "  task 3",
        "",
        "Done:",
        "  completed",
      })

      local sections = parser.get_sections()
      assert.equals(4, #sections)
      assert.equals("New", sections[1].name)
      assert.equals("Today", sections[2].name)
      assert.equals("Top This Week", sections[3].name)
      assert.equals("Done", sections[4].name)
    end)

    it("handles empty buffer", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
      local sections = parser.get_sections()
      assert.equals(0, #sections)
    end)

    it("handles buffer with no sections", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "just some text",
        "no sections here",
      })
      local sections = parser.get_sections()
      assert.equals(0, #sections)
    end)

    it("handles sections with trailing spaces", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:   ",
        "  task",
      })
      local sections = parser.get_sections()
      assert.equals(1, #sections)
      assert.equals("New", sections[1].name)
    end)
  end)

  describe("get_section_at_line", function()
    it("gets section at specific line", function()
      assert.equals("New", parser.get_section_at_line(2))
      assert.equals("Done", parser.get_section_at_line(5))
    end)

    it("returns section name for section header line", function()
      assert.equals("New", parser.get_section_at_line(1))
      assert.equals("Done", parser.get_section_at_line(4))
    end)

    it("returns section name for blank line in section", function()
      assert.equals("New", parser.get_section_at_line(3))
    end)

    it("returns nil for lines before first section", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "some preamble",
        "",
        "New:",
        "  task",
      })
      assert.is_nil(parser.get_section_at_line(1))
      assert.is_nil(parser.get_section_at_line(2))
      assert.equals("New", parser.get_section_at_line(3))
    end)

    it("returns nil for empty buffer", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
      assert.is_nil(parser.get_section_at_line(1))
    end)
  end)

  describe("get_section_range", function()
    it("gets section range", function()
      local start_line, end_line = parser.get_section_range("New")
      assert.equals(1, start_line)
      assert.equals(3, end_line)
    end)

    it("gets range for last section", function()
      local start_line, end_line = parser.get_section_range("Done")
      assert.equals(4, start_line)
      assert.equals(5, end_line) -- End of file
    end)

    it("returns nil for non-existent section", function()
      local start_line, end_line = parser.get_section_range("NoSuchSection")
      assert.is_nil(start_line)
      assert.is_nil(end_line)
    end)

    it("handles section at end of file", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "",
        "Done:",
      })
      local start_line, end_line = parser.get_section_range("Done")
      assert.equals(4, start_line)
      assert.equals(4, end_line)
    end)

    it("handles multiple sections correctly", function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New:",
        "  task 1",
        "",
        "Today:",
        "  task 2",
        "  task 3",
        "",
        "Done:",
        "  completed",
      })

      local start_line, end_line = parser.get_section_range("Today")
      assert.equals(4, start_line)
      assert.equals(7, end_line) -- Up to line before "Done:"
    end)
  end)
end)
