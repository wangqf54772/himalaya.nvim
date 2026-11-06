local state = require("himalaya.state")
local email = require("himalaya.email")
local himalaya = require("himalaya")
local windows = require("himalaya.ui.windows")
local runner = require("himalaya.cli.runner")

describe("UI Email Close and Reopen Lifecycle", function()
	local list_win

	local function setup_ui()
		state.reset_ui()
		state.current_account = ""
		state.current_folder = "INBOX"
		state.is_open = true
		state.tab = vim.api.nvim_get_current_tabpage()
		state.main = vim.api.nvim_create_buf(false, true)
		list_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(list_win, state.main)
		state.wins = { list = list_win }
		state.current_envelopes = { { id = "101", flags = {} } }
		state.email_buffers = {}
		state.email_state = {}
	end

	before_each(function()
		setup_ui()
		runner.set_mock(function(_, callback)
			callback(nil, "Test email body")
		end)
	end)

	after_each(function()
		runner.reset_mock()
		if windows.is_open() then
			windows.close()
		end
		if list_win and vim.api.nvim_win_is_valid(list_win) then
			pcall(vim.api.nvim_win_set_buf, list_win, vim.api.nvim_create_buf(false, true))
		end
		state.reset_ui()
	end)

	it("closes the reader buffer and returns to the listing", function()
		email.open()
		assert.truthy(windows.reader_visible())
		local reader = state.email

		email.close()

		assert.falsy(windows.reader_visible())
		assert.equals(state.main, vim.api.nvim_win_get_buf(list_win))
		assert.falsy(vim.api.nvim_buf_is_valid(reader))
		assert.truthy(windows.is_open())
	end)

	it("closes a reader buffer from a buffer tab without closing the UI", function()
		email.open()
		local reader = state.email
		assert.truthy(reader)

		assert.truthy(email.close_buffer(reader))

		assert.falsy(vim.api.nvim_buf_is_valid(reader))
		assert.truthy(windows.is_open())
		assert.equals(state.main, vim.api.nvim_win_get_buf(list_win))
		assert.falsy(windows.reader_visible())
	end)

	it("uses the open reader as the selected envelope", function()
		email.open()
		assert.equals("101", email.get_selected_envelope().id)
	end)

	it("resets state when the UI is closed and opens the reader after relaunch", function()
		email.open()
		assert.truthy(windows.reader_visible())

		himalaya.close()
		assert.falsy(state.is_open)
		assert.falsy(windows.is_open())
		assert.is_nil(state.main)

		setup_ui()
		state.current_envelopes = { { id = "102", flags = {} } }
		email.open()

		assert.truthy(windows.reader_visible())
		assert.equals("102", state.selected_email_id)
	end)

	it("intercepts :q in himalaya-email buffer to close only the reader", function()
		email.open()
		vim.api.nvim_set_current_buf(state.email)
		dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/ftplugin/himalaya-email.lua")

		local keymaps = vim.api.nvim_buf_get_keymap(state.email, "c")
		local found_q_interceptor = false
		for _, map in ipairs(keymaps) do
			if map.lhs == "<CR>" and map.expr == 1 then
				found_q_interceptor = true
				break
			end
		end
		assert.truthy(found_q_interceptor, "Expected buffer-local c mode mapping for <CR> to intercept :q")
	end)

	it("intercepts :bd in the reader so the reader window survives", function()
		email.open()
		local reader = state.email
		vim.api.nvim_set_current_buf(reader)
		dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/ftplugin/himalaya-email.lua")

		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":bd<CR>", true, false, true), "x", false)
		vim.wait(2000, function() return not windows.reader_visible() end, 50)

		assert.falsy(windows.reader_visible())
		assert.truthy(windows.is_open())
		assert.equals(state.main, vim.api.nvim_win_get_buf(list_win))
	end)
end)
