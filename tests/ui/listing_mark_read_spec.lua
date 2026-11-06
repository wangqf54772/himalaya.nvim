local state = require("himalaya.state")
local runner = require("himalaya.cli.runner")

describe("Listing mark-read mapping", function()
	local buf, original_leader

	before_each(function()
		state.reset_ui()
		original_leader = vim.g.mapleader
		vim.g.mapleader = " "

		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		state.main = buf
		state.current_account = "gmail"
		state.current_folder = "INBOX"
		state.current_envelopes = {
			{ id = "1", flags = {} },
			{ id = "2", flags = {} },
			{ id = "3", flags = {} },
		}
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })

		local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
		dofile(root .. "/ftplugin/himalaya-envelope-listing.lua")
	end)

	after_each(function()
		vim.g.mapleader = original_leader
		runner.reset_mock()
		state.reset_ui()
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end)

	local function mark_read_maps()
		local normal, visual = false, false
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
			if map.desc == "Mark read" then
				normal = true
			end
		end
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "x")) do
			if map.desc == "Mark read" then
				visual = true
			end
		end
		return normal, visual
	end

	it("maps <leader>R in normal and visual mode", function()
		local normal, visual = mark_read_maps()
		assert.truthy(normal, "expected a normal-mode mark-read mapping")
		assert.truthy(visual, "expected a visual-mode mark-read mapping")
	end)

	it("marks every envelope in the visual selection", function()
		local executed = nil
		runner.set_mock(function(cmd, callback)
			executed = cmd
			callback(nil, "ok")
		end)

		-- select lines 1-3 and press <leader>R
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("V2j", true, false, true), "x", false)
		vim.api.nvim_feedkeys(" R", "x", false)

		assert.truthy(executed, "expected flag add to run")
		assert.equals("n", vim.fn.mode(), "visual mode should end after marking")
		local str = table.concat(executed, " ")
		assert.contains(str, "flag add")
		assert.contains(str, "1")
		assert.contains(str, "2")
		assert.contains(str, "3")
	end)
end)
