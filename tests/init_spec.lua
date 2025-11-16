-- init_spec.lua - Smoke tests for NeoTODO plugin

local neotodo = require("neotodo")

describe("neotodo", function()
	it("can be required", function()
		assert.is_not_nil(neotodo)
	end)

	it("can call setup without errors", function()
		neotodo.setup()
		assert.is_true(true)
	end)

	it("has a version string", function()
		assert.is_not_nil(neotodo.version)
		assert.equals("string", type(neotodo.version))
	end)

	it("merges user config with defaults", function()
		neotodo.setup({ task_indent = 4 })
		local config = require("neotodo.config")
		assert.equals(4, config.options.task_indent)
	end)

	it("preserves defaults when no config provided", function()
		neotodo.setup()
		local config = require("neotodo.config")
		assert.equals(2, config.options.task_indent)
		assert.equals("TODO.txt", config.options.file_pattern)
	end)
end)
