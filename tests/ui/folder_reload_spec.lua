local state = require("himalaya.state")
local folder = require("himalaya.folder")
local runner = require("himalaya.cli.runner")
local fixtures = require("fixtures.v2_fixtures")

describe("Folder reload", function()
	before_each(function()
		state.current_account = "jlu"
		state.current_folder = "INBOX"
		state.current_page = 2
		state.sidebar = vim.api.nvim_create_buf(false, true)
		state.main = vim.api.nvim_create_buf(false, true)
		state.sidebar_popup = nil
		state.main_popup = nil
		require("himalaya.cache").clear()
	end)

	after_each(function()
		runner.reset_mock()
		require("himalaya.cache").clear()
	end)

	it("reloads envelopes for the current account, mailbox and page", function()
		local envelope_cmd = nil
		runner.set_mock(function(cmd, callback)
			local joined = table.concat(cmd, " ")
			if joined:find("mailbox list", 1, true) then
				callback(nil, fixtures.mailboxes_json)
			elseif joined:find("envelope list", 1, true) then
				envelope_cmd = cmd
				callback(nil, '{"envelopes":[]}')
			else
				callback(nil, "{}")
			end
		end)

		folder.reload()

		assert.truthy(envelope_cmd, "reload must list envelopes")
		local str = table.concat(envelope_cmd, " ")
		assert.contains(str, "--account jlu")
		assert.contains(str, "-m INBOX")
		assert.contains(str, "-p 2")
	end)
end)
