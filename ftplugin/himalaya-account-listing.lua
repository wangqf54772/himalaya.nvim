-- Keybindings for himalaya-account-listing buffer
local bufnr = vim.api.nvim_get_current_buf()
local state = require("himalaya.state")

local function account_under_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return state.account_lines and state.account_lines[line]
end

local function switch_account()
	local name = account_under_cursor()
	if not name then
		return
	end

	require("himalaya.account").switch_to(name)
	require("himalaya.ui.windows").focus_list()
end

vim.keymap.set("n", "<CR>", switch_account, {
	buffer = bufnr,
	nowait = true,
	desc = "Switch account",
})

vim.keymap.set("n", "<LeftMouse>", function()
	local mouse = vim.fn.getmousepos()
	if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
		return
	end
	if vim.api.nvim_win_get_buf(mouse.winid) ~= bufnr or mouse.line < 1 then
		return
	end

	vim.api.nvim_set_current_win(mouse.winid)
	pcall(vim.api.nvim_win_set_cursor, mouse.winid, { mouse.line, 0 })
	switch_account()
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Switch account",
})
