local state = require("himalaya.state")
local email = require("himalaya.email")
local runner = require("himalaya.cli.runner")

describe("UI Email CRLF Sanitization", function()
	local list_win

	before_each(function()
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
	end)

	after_each(function()
		runner.reset_mock()
		if list_win and vim.api.nvim_win_is_valid(list_win) then
			pcall(vim.api.nvim_win_set_buf, list_win, vim.api.nvim_create_buf(false, true))
		end
		for _, buf in pairs(state.email_buffers or {}) do
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		state.reset_ui()
	end)

	it("sanitizes CRLF so email body buffer has no carriage return (^M) characters", function()
		runner.set_mock(function(_, callback)
			callback(nil, "Header: Value\r\n\r\nLine 1\r\nLine 2\r\nLine 3\r\n")
		end)

		email.open()

		local lines = vim.api.nvim_buf_get_lines(state.email, 0, -1, false)
		assert.equals(5, #lines)
		assert.equals("Header: Value", lines[1])
		assert.equals("", lines[2])
		assert.equals("Line 1", lines[3])
		assert.equals("Line 2", lines[4])
		assert.equals("Line 3", lines[5])

		for idx, line in ipairs(lines) do
			assert.falsy(line:find("\r"), string.format("Line %d contains \\r (^M)", idx))
		end
	end)
end)
