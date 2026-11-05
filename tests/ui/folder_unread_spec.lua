local folder_list = require("himalaya.ui.folder_list")
local state = require("himalaya.state")
local Popup = require("nui.popup")

describe("UI Folder List Unread Counts", function()
	local sidebar_popup

	before_each(function()
		sidebar_popup = Popup({ enter = false })
		local winid = vim.api.nvim_get_current_win()
		sidebar_popup.winid = winid
		vim.api.nvim_win_set_buf(winid, sidebar_popup.bufnr)
		state.sidebar = sidebar_popup.bufnr
		state.sidebar_popup = sidebar_popup
		state.current_folder = "INBOX"
	end)

	after_each(function()
		require("himalaya.cli.runner").reset_mock()
		state.current_account = ""
	end)

	it("renders unread count in parentheses for folders with unread > 0", function()
		local mailboxes = {
			{ id = "INBOX", name = "INBOX", total = 42, unread = 7 },
			{ id = "Archive", name = "Archive", total = 100, unread = 0 },
			{ id = "Drafts", name = "Drafts", total = 5, unread = nil },
		}

		folder_list.render(sidebar_popup.bufnr, mailboxes)

		local lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.equals(3, #lines)

		assert.truthy(lines[1]:find("INBOX %(7%)"), "INBOX line should display (7) unread count")
		assert.falsy(lines[2]:find("%(0%)"), "Archive line should not display (0)")
		assert.falsy(lines[2]:find("%("), "Archive line should not have parentheses")
		assert.falsy(lines[3]:find("%("), "Drafts line should not have parentheses")
	end)

	it("renders unread count on nested folders", function()
		local mailboxes = {
			{ id = "Work/Urgent", name = "Work/Urgent", total = 10, unread = 3 },
			{ id = "Work/Later", name = "Work/Later", total = 5, unread = 0 },
		}

		folder_list.render(sidebar_popup.bufnr, mailboxes)

		local lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.equals(3, #lines) -- Work, Urgent, Later
		assert.truthy(lines[1]:find("Work %(3%)"), "Parent Work folder should aggregate unread count (3)")
		assert.truthy(lines[2]:find("Urgent %(3%)"), "Urgent child folder should display (3)")
		assert.falsy(lines[3]:find("%("), "Later child folder should not display unread count")
	end)

	it("adjusts cached folder unread count and re-renders sidebar", function()
		local cache = require("himalaya.cache")
		local mailboxes = {
			{ id = "INBOX", name = "INBOX", total = 10, unread = 2 },
		}
		cache.set_folders(mailboxes)
		folder_list.render(sidebar_popup.bufnr, mailboxes)

		local lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.truthy(lines[1]:find("INBOX %(2%)"))

		cache.adjust_folder_unread("INBOX", -1)
		folder_list.render(sidebar_popup.bufnr, cache.get_folders())

		lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.truthy(lines[1]:find("INBOX %(1%)"))

		cache.adjust_folder_unread("INBOX", -1)
		folder_list.render(sidebar_popup.bufnr, cache.get_folders())

		lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.falsy(lines[1]:find("%("))
	end)

	it("fills unread counts through a background request", function()
		local runner = require("himalaya.cli.runner")
		local fixtures = require("fixtures.v2_fixtures")
		state.current_account = "gmail"

		local executed_cmd = nil
		runner.set_mock(function(cmd, callback)
			executed_cmd = cmd
			callback(nil, fixtures.mailboxes_json)
		end)

		folder_list.refresh_counts("gmail", sidebar_popup.bufnr)

		assert.truthy(executed_cmd)
		local cmd_str = table.concat(executed_cmd, " ")
		assert.truthy(cmd_str:match("mailbox list"))
		assert.truthy(cmd_str:match("%-%-counts"), "counts refresh must ask for --counts")

		local lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.truthy(lines[1]:find("INBOX %(3%)"), "sidebar should get the unread badge")
	end)

	it("drops counts that arrive after the account changed", function()
		local runner = require("himalaya.cli.runner")
		local fixtures = require("fixtures.v2_fixtures")
		state.current_account = "gmail"

		local deliver = nil
		runner.set_mock(function(_, callback)
			deliver = callback
		end)

		folder_list.refresh_counts("gmail", sidebar_popup.bufnr)
		assert.truthy(deliver, "expected the counts request to be started")

		-- The user switches account and the sidebar is painted for the new one
		-- before the old counts response lands.
		state.current_account = "other"
		folder_list.render(sidebar_popup.bufnr, { { id = "INBOX", name = "INBOX", total = 1, unread = 1 } })
		deliver(nil, fixtures.mailboxes_json)

		local lines = vim.api.nvim_buf_get_lines(sidebar_popup.bufnr, 0, -1, false)
		assert.truthy(lines[1]:find("INBOX %(1%)"), "stale counts must not overwrite the new account")
		assert.falsy(lines[1]:find("INBOX %(3%)"))
	end)
end)
