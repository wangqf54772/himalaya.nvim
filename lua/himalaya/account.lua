local state = require("himalaya.state")
local picker = require("himalaya.ui.picker")
local folder = require("himalaya.folder")

local M = {}

function M.select()
	picker.select_account(function(choice)
		M.switch_to(choice.name)
	end)
end

function M.switch_to(account_name)
	state.current_account = account_name
	state.current_folder = nil
	state.current_page = 1

	-- Cached folders and envelopes belong to the previous account.
	require("himalaya.cache").clear()

	-- The reader pane would still show a message from the previous account.
	pcall(function()
		require("himalaya.email").close()
	end)

	vim.notify("Switched to account: " .. account_name, vim.log.levels.INFO)
	folder.reload()
end

return M
