-- Keybindings for himalaya-folder-listing buffer
local bufnr = vim.api.nvim_get_current_buf()
local state = require("himalaya.state")

local function folder_under_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return state.folder_lines and state.folder_lines[line]
end

local function open_folder(focus_list)
	local name = folder_under_cursor()
	if not name then
		return
	end

	require("himalaya.folder").switch_to(name)

	if focus_list then
		require("himalaya.ui.windows").focus_list()
	end
end

vim.keymap.set("n", "<CR>", function()
	open_folder(true)
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Open mailbox",
})

require("himalaya.ui.mouse").attach(bufnr)
