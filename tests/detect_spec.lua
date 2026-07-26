describe("detect", function()
  local detect = require('neotodo.detect')

  after_each(function()
    vim.cmd('bufdo! bwipeout!')
  end)

  describe("is_todo_filename", function()
    it("matches the plain TODO.txt variants", function()
      assert.is_true(detect.is_todo_filename('TODO.txt'))
      assert.is_true(detect.is_todo_filename('todo.txt'))
    end)

    it("matches TODO_<something>.txt variants", function()
      assert.is_true(detect.is_todo_filename('TODO_work.txt'))
      assert.is_true(detect.is_todo_filename('todo_work.txt'))
      assert.is_true(detect.is_todo_filename('TODO_2026_q3.txt'))
    end)

    it("rejects unrelated files", function()
      assert.is_false(detect.is_todo_filename('notes.txt'))
      assert.is_false(detect.is_todo_filename('TODO_work.md'))
      assert.is_false(detect.is_todo_filename('TODO_.txt'))
      assert.is_false(detect.is_todo_filename('MYTODO.txt'))
      assert.is_false(detect.is_todo_filename('Todo_work.txt'))
    end)
  end)

  describe("is_todo_buffer", function()
    local function buffer_named(name)
      vim.cmd('enew')
      local bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_name(bufnr, name)
      return bufnr
    end

    it("returns false for unnamed buffers", function()
      vim.cmd('enew')
      assert.is_false(detect.is_todo_buffer(vim.api.nvim_get_current_buf()))
    end)

    it("matches TODO files by their tail", function()
      assert.is_true(detect.is_todo_buffer(buffer_named('/tmp/neotodo/TODO.txt')))
      assert.is_true(detect.is_todo_buffer(buffer_named('/tmp/neotodo/TODO_work.txt')))
      -- Separate directory: macOS filesystems treat TODO_work.txt and todo_work.txt
      -- as the same path, so Vim would refuse the second buffer name
      assert.is_true(detect.is_todo_buffer(buffer_named('/tmp/neotodo/lower/todo_work.txt')))
    end)

    it("matches focus mode buffers", function()
      assert.is_true(detect.is_todo_buffer(buffer_named('/tmp/neotodo/TODO.txt [Focus]')))
      assert.is_true(detect.is_todo_buffer(buffer_named('/tmp/neotodo/TODO_work.txt [Focus]')))
    end)

    it("rejects non-TODO buffers", function()
      assert.is_false(detect.is_todo_buffer(buffer_named('/tmp/neotodo/notes.txt')))
      assert.is_false(detect.is_todo_buffer(buffer_named('/tmp/TODO_dir/notes.txt')))
    end)
  end)
end)
