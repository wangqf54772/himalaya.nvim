local state = require("himalaya.state")
local windows = require("himalaya.ui.windows")
local runner = require("himalaya.cli.runner")
local fixtures = require("fixtures.v2_fixtures")

describe("Native window UI", function()
	before_each(function()
		state.reset_ui()
		state.current_account = ""
		runner.set_mock(function(cmd, callback)
			local str = table.concat(cmd, " ")
			if str:find("account list", 1, true) then
				callback(nil, fixtures.accounts_json)
			elseif str:find("mailbox list", 1, true) then
				callback(nil, fixtures.mailboxes_json)
			elseif str:find("envelope list", 1, true) then
				callback(nil, '{"envelopes":[]}')
			else
				callback(nil, "{}")
			end
		end)
	end)

	after_each(function()
		runner.reset_mock()
		if windows.is_open() then
			windows.close()
		end
		state.reset_ui()
	end)

	it("creates a dedicated tab with folders, accounts and list windows", function()
		local before = #vim.api.nvim_list_tabpages()
		windows.create()

		assert.equals(before + 1, #vim.api.nvim_list_tabpages())
		assert.equals(3, #vim.api.nvim_tabpage_list_wins(0))
		assert.truthy(windows.in_himalaya_tab())
		assert.equals(state.main, vim.api.nvim_win_get_buf(state.wins.list))
		assert.equals(state.sidebar, vim.api.nvim_win_get_buf(state.wins.folders))
		assert.equals(state.accounts, vim.api.nvim_win_get_buf(state.wins.accounts))

		assert.truthy(vim.bo[state.main].buflisted)
		assert.falsy(vim.bo[state.sidebar].buflisted)
		assert.falsy(vim.bo[state.accounts].buflisted)
		assert.equals("himalaya-envelope-listing", vim.bo[state.main].filetype)
		assert.equals("himalaya-folder-listing", vim.bo[state.sidebar].filetype)
		assert.equals("himalaya-account-listing", vim.bo[state.accounts].filetype)
		assert.truthy(vim.b[state.main].himalaya_buffer)
		assert.equals(vim.wo[state.wins.folders].winfixwidth, true)
		assert.equals(vim.wo[state.wins.accounts].winfixheight, true)
	end)

	it("closes the tab and wipes its buffers", function()
		local before = #vim.api.nvim_list_tabpages()
		windows.create()
		local main, sidebar, accounts = state.main, state.sidebar, state.accounts

		windows.close()

		assert.equals(before, #vim.api.nvim_list_tabpages())
		assert.falsy(windows.is_open())
		assert.falsy(vim.api.nvim_buf_is_valid(main))
		assert.falsy(vim.api.nvim_buf_is_valid(sidebar))
		assert.falsy(vim.api.nvim_buf_is_valid(accounts))
	end)
end)
