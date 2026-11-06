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

	-- Reader buffers hold messages from the previous account.
	pcall(function()
		require("himalaya.email").close_all()
	end)

	vim.notify("Switched to account: " .. account_name, vim.log.levels.INFO)

	if state.accounts and vim.api.nvim_buf_is_valid(state.accounts) then
		require("himalaya.ui.account_list").refresh(state.accounts)
	end

	folder.reload()
end

return M
