-- Keybindings for himalaya-email buffer
local bufnr = vim.api.nvim_get_current_buf()
local config = require("himalaya.config")
local keymap_util = require("himalaya.utils.keymap")
local email_mod = require("himalaya.email")
local actions_mod = require("himalaya.actions")
local keymap_help = require("himalaya.ui.keymap_help")

-- Define actions for email reading pane
local actions = {
	show_keymaps = function()
		keymap_help.open("Himalaya email keymaps", config.config.keymaps.email)
	end,

	close_email = function()
		email_mod.close()
	end,

	toggle_html = function()
		email_mod.toggle_html()
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
}

-- Apply keymaps from config
keymap_util.apply(bufnr, config.config.keymaps.email, actions)

-- Intercept closing commands to close only the reader buffer and return to the
-- listing, instead of letting :bdelete close the reader window.
local close_commands = {
	q = true,
	["q!"] = true,
	quit = true,
	close = true,
	bd = true,
	["bd!"] = true,
	bdelete = true,
	["bdelete!"] = true,
	bw = true,
	["bw!"] = true,
	bwipeout = true,
	["bwipeout!"] = true,
}

vim.keymap.set("c", "<CR>", function()
	if vim.fn.getcmdtype() == ":" then
		local cmd = vim.fn.getcmdline():match("^%s*(.-)%s*$")
		if close_commands[cmd] then
			return "<C-u>lua require('himalaya.email').close()<CR>"
		end
	end
	return "<CR>"
end, { expr = true, buffer = bufnr })
