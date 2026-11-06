local state = require("himalaya.state")
local windows = require("himalaya.ui.windows")
local mouse = require("himalaya.ui.mouse")
local runner = require("himalaya.cli.runner")
local fixtures = require("fixtures.v2_fixtures")

describe("Himalaya mouse dispatcher", function()
	local original_getmousepos

	before_each(function()
		state.reset_ui()
		state.current_account = ""
		original_getmousepos = vim.fn.getmousepos

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

		windows.create()
	end)

	after_each(function()
		vim.fn.getmousepos = original_getmousepos
		runner.reset_mock()
		if windows.is_open() then
			windows.close()
		end
		state.reset_ui()
	end)

	local function click(win, line)
		vim.fn.getmousepos = function()
			return { winid = win, line = line, column = 0 }
		end
		mouse.click()
	end

	it("switches folder and keeps the focus in the folders pane", function()
		local target = state.folder_list[2]
		local line = nil
		for l, name in pairs(state.folder_lines) do
			if name == target then
				line = l
			end
		end
		assert.truthy(target and line)

		vim.api.nvim_set_current_win(state.wins.list)
		click(state.wins.folders, line)

		assert.equals(state.wins.folders, vim.api.nvim_get_current_win())
		assert.equals(target, state.current_folder)
		assert.equals(line, vim.api.nvim_win_get_cursor(state.wins.folders)[1])
	end)

	it("switches account and keeps the focus in the accounts pane", function()
		local line = 2
		vim.api.nvim_set_current_win(state.wins.list)
		click(state.wins.accounts, line)

		assert.equals(state.wins.accounts, vim.api.nvim_get_current_win())
		assert.equals("work", state.current_account)
		assert.equals(line, vim.api.nvim_win_get_cursor(state.wins.accounts)[1])
	end)

	it("only selects when clicking the envelope list", function()
		state.email = nil
		vim.api.nvim_set_current_win(state.wins.folders)
		click(state.wins.list, 1)

		assert.equals(state.wins.list, vim.api.nvim_get_current_win())
		assert.is_nil(state.email)
		assert.equals(1, vim.api.nvim_win_get_cursor(state.wins.list)[1])
	end)
end)
