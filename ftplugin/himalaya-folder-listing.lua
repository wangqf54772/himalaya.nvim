-- Keybindings for himalaya-folder-listing buffer
local bufnr = vim.api.nvim_get_current_buf()
local state = require("himalaya.state")

local function folder_under_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return state.folder_lines and state.folder_lines[line]
end

local function open_folder()
	local name = folder_under_cursor()
	if not name then
		return
	end

	require("himalaya.folder").switch_to(name)

	-- Hand focus back to the envelope list so navigation keeps working.
	local main_win = state.main and vim.fn.bufwinid(state.main) or -1
	if main_win ~= -1 then
		vim.api.nvim_set_current_win(main_win)
	end
end

vim.keymap.set("n", "<CR>", open_folder, {
	buffer = bufnr,
	nowait = true,
	desc = "Open mailbox",
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
	open_folder()
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Open mailbox",
})
