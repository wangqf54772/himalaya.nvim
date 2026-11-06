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
local state = require("himalaya.state")

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

	mark_read = function()
		actions_mod.mark_read()
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

-- <leader>R also works on a visual selection of envelopes.
local mark_read_key = nil
for key, action in pairs(config.config.keymaps.listing) do
	if action == "mark_read" then
		mark_read_key = key
		break
	end
end
if mark_read_key then
	vim.keymap.set("x", mark_read_key, function()
		local first = vim.fn.line("v")
		local last = vim.fn.line(".")
		if first > last then
			first, last = last, first
		end

		local envelopes = {}
		for i = first, last do
			if state.current_envelopes[i] then
				table.insert(envelopes, state.current_envelopes[i])
			end
		end

		-- Leave visual mode before the async CLI call.
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
		actions_mod.mark_read(envelopes)
	end, {
		buffer = bufnr,
		nowait = true,
		desc = "Mark read",
	})
end

-- Single click is handled by the shared dispatcher; double click opens.
require("himalaya.ui.mouse").attach(bufnr)

vim.keymap.set("n", "<2-LeftMouse>", function()
	local mouse = vim.fn.getmousepos()
	if not mouse.line or mouse.line < 1 then
		return
	end
	if mouse.winid ~= require("himalaya.state").wins.list then
		return
	end
	if vim.api.nvim_win_get_buf(mouse.winid) ~= bufnr then
		return
	end
	email_mod.open()
end, {
	buffer = bufnr,
	nowait = true,
	desc = "Open email",
})
