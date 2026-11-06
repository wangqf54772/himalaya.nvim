-- Keybindings for himalaya-envelope-listing buffer
local bufnr = vim.api.nvim_get_current_buf()
local config = require("himalaya.config")
local keymap_util = require("himalaya.utils.keymap")
local folder_mod = require("himalaya.folder")
local page_mod = require("himalaya.page")
local email_mod = require("himalaya.email")
local himalaya = require("himalaya")
local actions_mod = require("himalaya.actions")
local account_mod = require("himalaya.account")
local keymap_help = require("himalaya.ui.keymap_help")

-- Define actions
local actions = {
	show_keymaps = function()
		keymap_help.open("Himalaya email listing keymaps", config.config.keymaps.listing)
	end,

	close = function()
		himalaya.close()
	end,

	next_folder = function()
		local count = vim.v.count1
		local start_folder = require("himalaya.state").current_folder

		for _ = 1, count do
			folder_mod.next(true, true)
		end

		local end_folder = require("himalaya.state").current_folder
		if start_folder ~= end_folder then
			folder_mod.reload()
		end
	end,

	previous_folder = function()
		local count = vim.v.count1
		local start_folder = require("himalaya.state").current_folder

		for _ = 1, count do
			folder_mod.previous(true, true)
		end

		local end_folder = require("himalaya.state").current_folder
		if start_folder ~= end_folder then
			folder_mod.reload()
		end
	end,

	folder_picker = function()
		folder_mod.picker()
	end,

	account_picker = function()
		account_mod.select()
	end,

	reload = function()
		folder_mod.reload()
	end,

	next_page = function()
		page_mod.next(vim.v.count1)
	end,

	previous_page = function()
		page_mod.previous(vim.v.count1)
	end,

	open_email = function()
		email_mod.open()
	end,

	compose = function()
		actions_mod.compose()
	end,

	reply = function()
		actions_mod.reply()
	end,

	forward = function()
		actions_mod.forward()
	end,

	delete = function()
		actions_mod.delete()
	end,

	move = function()
		actions_mod.move()
	end,

	copy = function()
		actions_mod.copy()
	end,

	download_attachments = function()
		actions_mod.download_attachments()
	end,

	flag_add = function()
		actions_mod.flag_add()
	end,

	flag_remove = function()
		actions_mod.flag_remove()
	end,

	search = function()
		actions_mod.search()
	end,
}

-- Apply keymaps from config
keymap_util.apply(bufnr, config.config.keymaps.listing, actions)

-- Single click selects the row (and focuses the listing), double click opens
-- the email.
local function select_under_mouse()
	local mouse = vim.fn.getmousepos()
	if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
		return false
	end
	if vim.api.nvim_win_get_buf(mouse.winid) ~= bufnr or mouse.line < 1 then
		return false
	end

	vim.api.nvim_set_current_win(mouse.winid)
	pcall(vim.api.nvim_win_set_cursor, mouse.winid, { mouse.line, 0 })
	return true
end

vim.keymap.set("n", "<LeftMouse>", select_under_mouse, {
	buffer = bufnr,
	nowait = true,
	desc = "Select email",
})

vim.keymap.set("n", "<2-LeftMouse>", function()
	if select_under_mouse() then
		email_mod.open()
	end
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Open email",
})
