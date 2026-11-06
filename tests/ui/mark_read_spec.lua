local state = require("himalaya.state")
local actions = require("himalaya.actions")
local runner = require("himalaya.cli.runner")
local cache = require("himalaya.cache")

describe("Mark read", function()
	before_each(function()
		state.reset_ui()
		state.current_account = "gmail"
		state.current_folder = "INBOX"
		state.main = vim.api.nvim_create_buf(false, true)
		state.current_envelopes = {
			{ id = "1", flags = {} },
			{ id = "2", flags = { { iana = "seen", raw = "\\Seen" } } },
			{ id = "3", flags = {} },
		}
		cache.set_folders({ { id = "INBOX", name = "INBOX", unread = 5 } })
	end)

	after_each(function()
		runner.reset_mock()
		cache.clear()
		state.reset_ui()
	end)

	it("marks the given envelopes and updates the unread counts", function()
		local executed = nil
		runner.set_mock(function(cmd, callback)
			executed = cmd
			callback(nil, "ok")
		end)

		actions.mark_read({ state.current_envelopes[1], state.current_envelopes[3] })

		assert.truthy(executed)
		local str = table.concat(executed, " ")
		assert.contains(str, "flag add")
		assert.contains(str, "-f seen")
		assert.contains(str, "1")
		assert.contains(str, "3")

		assert.equals("seen", state.current_envelopes[1].flags[1].iana)
		assert.equals("seen", state.current_envelopes[3].flags[1].iana)
		assert.equals(3, cache.get_folders()[1].unread)
	end)
end)
