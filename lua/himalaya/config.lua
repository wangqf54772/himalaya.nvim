local M = {}

M.config = {
	sidebar = {
		width = 30,
	},
	accounts_height = 6, -- height of the accounts section at the bottom of the sidebar
	border = "single", -- border style for nui popups: "single", "rounded", "double", etc.
	wrap_folder_navigation = true, -- wrap to first/last when navigating folders
	icons_enabled = false, -- use nerd font icons for folders
	custom_select = nil, -- optional custom picker function: fn(items, opts, on_choice)
	render_html = false, -- render HTML bodies to plain text instead of raw markup
	prefer_html = false, -- prefer the HTML body over text/plain when both exist
	html_renderer = "w3m", -- w3m, lynx or pandoc; must read a local HTML file
	refresh_interval = 600, -- seconds between automatic refreshes, 0 disables it
	refresh_focus_debounce = 10, -- seconds to ignore repeated FocusGained refreshes
	keymaps = {
		listing = {
			["g?"] = "show_keymaps",
			["gq"] = "close",
			["]f"] = "next_folder",
			["[f"] = "previous_folder",
			["gF"] = "folder_picker",
			["gA"] = "account_picker",
			["R"] = "reload",
			["]]"] = "next_page",
			["[["] = "previous_page",
			["<CR>"] = "open_email",
			["gw"] = "compose",
			["c"] = "compose",
			["gr"] = "reply",
			["r"] = "reply",
			["gf"] = "forward",
			["gD"] = "delete",
			["d"] = "delete",
			["gM"] = "move",
			["m"] = "move",
			["gC"] = "copy",
			["ga"] = "download_attachments",
			["<leader>R"] = "mark_read",
			["gFa"] = "flag_add",
			["gFr"] = "flag_remove",
			["g/"] = "search",
		},
		email = {
			["g?"] = "show_keymaps",
			["gq"] = "close_email",
			["q"] = "close_email",
			["gH"] = "toggle_html",
			["gr"] = "reply",
			["r"] = "reply",
			["gf"] = "forward",
			["gD"] = "delete",
			["d"] = "delete",
			["gM"] = "move",
			["m"] = "move",
			["gC"] = "copy",
			["ga"] = "download_attachments",
			["gFa"] = "flag_add",
			["gFr"] = "flag_remove",
		},
	},
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.get_border_style()
	if type(M.config.border) == "table" and M.config.border.style then
		return M.config.border.style
	elseif M.config.border then
		return M.config.border
	end
	return "single"
end

return M
