local state = require("himalaya.state")
local config = require("himalaya.config")
local refresh = require("himalaya.refresh")
local windows = require("himalaya.ui.windows")
local runner = require("himalaya.cli.runner")
local fixtures = require("fixtures.v2_fixtures")

describe("Automatic refresh", function()
	local original_interval, original_debounce
	local envelope_calls

	before_each(function()
		state.reset_ui()
		state.current_account = ""
		envelope_calls = 0
		original_interval = config.config.refresh_interval
		original_debounce = config.config.refresh_focus_debounce

		runner.set_mock(function(cmd, callback)
			local str = table.concat(cmd, " ")
			if str:find("account list", 1, true) then
				callback(nil, fixtures.accounts_json)
			elseif str:find("mailbox list", 1, true) then
				callback(nil, fixtures.mailboxes_json)
			elseif str:find("envelope list", 1, true) then
				envelope_calls = envelope_calls + 1
				callback(nil, '{"envelopes":[]}')
			else
				callback(nil, "{}")
			end
		end)

		windows.create()
	end)

	after_each(function()
		refresh.teardown()
		config.config.refresh_interval = original_interval
		config.config.refresh_focus_debounce = original_debounce
		runner.reset_mock()
		if windows.is_open() then
			windows.close()
		end
		state.reset_ui()
	end)

	it("is enabled with a 10 minute default", function()
		assert.equals(600, original_interval)
	end)

	it("arms a timer while the UI is open", function()
		vim.wait(200, function() return state.refresh_timer ~= nil end, 20)
		assert.truthy(state.refresh_timer, "expected a refresh timer")
	end)

	it("releases the timer when the UI closes", function()
		vim.wait(200, function() return state.refresh_timer ~= nil end, 20)
		windows.close()
		assert.is_nil(state.refresh_timer)
	end)

	it("does not arm a timer when the interval is 0", function()
		config.config.refresh_interval = 0
		refresh.teardown()
		state.refresh_timer = nil
		refresh.schedule()
		assert.is_nil(state.refresh_timer)
	end)

	it("refreshes the visible listing when triggered", function()
		local before = envelope_calls
		refresh.refresh({ notify = false })
		vim.wait(2000, function() return envelope_calls > before end, 50)
		assert.truthy(envelope_calls > before, "expected an envelope list request")
	end)

	it("ignores refreshes while the Himalaya tabpage is not current", function()
		local before = envelope_calls
		vim.cmd("tabnew")
		refresh.refresh({ notify = false })
		vim.wait(300, function() return false end, 50)
		assert.equals(before, envelope_calls)
		vim.cmd("tabclose")
	end)

	it("restarts the countdown after a manual reload", function()
		local first = state.refresh_timer
		assert.truthy(first)
		require("himalaya.folder").reload()
		assert.truthy(state.refresh_timer)
		assert.truthy(state.refresh_timer ~= first, "expected a fresh timer")
	end)

	it("resolves the mailbox before listing envelopes after an account switch", function()
		local folder = require("himalaya.folder")
		local cache = require("himalaya.cache")

		-- account.switch_to() clears the mailbox before reloading.
		state.current_folder = nil
		cache.clear()

		local envelope_calls = 0
		runner.set_mock(function(cmd, callback)
			local str = table.concat(cmd, " ")
			if str:find("account list", 1, true) then
				callback(nil, fixtures.accounts_json)
			elseif str:find("mailbox list", 1, true) then
				callback(nil, fixtures.mailboxes_json)
			elseif str:find("envelope list", 1, true) then
				envelope_calls = envelope_calls + 1
				callback(nil, '{"envelopes":[]}')
			else
				callback(nil, "{}")
			end
		end)

		local err
		folder.reload(function(e)
			err = e
		end)
		vim.wait(2000, function()
			return state.current_folder ~= nil and envelope_calls > 0
		end, 50)

		assert.is_nil(err)
		assert.truthy(state.current_folder, "the mailbox list should resolve the default mailbox")
		assert.truthy(envelope_calls > 0, "envelopes are listed once the mailbox is known")
	end)
end)
