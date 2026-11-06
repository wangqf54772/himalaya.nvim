-- Keybindings for himalaya-account-listing buffer
local bufnr = vim.api.nvim_get_current_buf()
local state = require("himalaya.state")

local function account_under_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return state.account_lines and state.account_lines[line]
end

local function switch_account(focus_list)
	local name = account_under_cursor()
	if not name then
		return
	end

	require("himalaya.account").switch_to(name)

	if focus_list then
		require("himalaya.ui.windows").focus_list()
	end
end

vim.keymap.set("n", "<CR>", function()
	switch_account(true)
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Switch account",
})

require("himalaya.ui.mouse").attach(bufnr)
