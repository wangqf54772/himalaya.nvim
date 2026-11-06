local state = require("himalaya.state")
local config = require("himalaya.config")
local cache = require("himalaya.cache")
local account_list = require("himalaya.ui.account_list")
local folder_cli = require("himalaya.cli.folder")
local envelope_cli = require("himalaya.cli.envelope")
local folder_list = require("himalaya.ui.folder_list")
local envelope_list = require("himalaya.ui.envelope_list")

local M = {}

local function escape_winbar(text)
	return (text or ""):gsub("%%", "%%%%")
end

local function winbar(text)
	return " %#HimalayaWinbar#" .. escape_winbar(text) .. " "
end

local function set_win_opts(win, opts)
	opts = opts or {}
	local wo = vim.wo[win]
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.foldcolumn = "0"
	wo.wrap = opts.wrap or false
	wo.spell = false
	wo.list = false
	wo.winfixwidth = opts.fix_width or false
	wo.winfixheight = opts.fix_height or false
	wo.winbar = opts.winbar or ""
	if vim.fn.exists("+winfixbuf") == 1 then
		wo.winfixbuf = opts.fix_buf or false
	end
end

local function unique_name(name)
	local candidate = name
	local i = 1
	while vim.fn.bufnr(candidate) ~= -1 do
		i = i + 1
		candidate = name .. " (" .. i .. ")"
	end
	return candidate
end

--- Creates a scratch buffer used by the Himalaya windows.
---@param name string
---@param filetype string
---@param listed boolean
---@return integer
function M.create_buffer(name, filetype, listed)
	local buf = vim.api.nvim_create_buf(listed, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = listed and true or false
	vim.bo[buf].modifiable = false
	pcall(vim.api.nvim_buf_set_name, buf, unique_name(name))
	vim.bo[buf].filetype = filetype
	if listed then
		vim.b[buf].himalaya_buffer = true
	end
	return buf
end

function M.is_open()
	return state.is_open == true and state.tab ~= nil and vim.api.nvim_tabpage_is_valid(state.tab)
end

function M.in_himalaya_tab()
	return state.tab ~= nil and vim.api.nvim_get_current_tabpage() == state.tab
end

function M.is_himalaya_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].himalaya_buffer == true
end

function M.is_sidebar_window(win)
	return win ~= nil and (win == state.wins.folders or win == state.wins.accounts)
end

function M.focus_list()
	local win = state.wins.list
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_set_current_win, win)
	end
end

function M.reader_visible()
	local win = state.wins.list
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	return buf ~= state.main and state.email_state[buf] ~= nil
end

function M.update_list_status()
	local win = state.wins.list
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if vim.api.nvim_win_get_buf(win) ~= state.main then
		return
	end

	local folder = state.current_folder or "Inbox"
	local page = state.current_page or 1
	local total = state.current_envelope_count or 0
	vim.wo[win].winbar = winbar(("%s · Page %d · %d emails"):format(folder, page, total))
end

function M.update_active_winbar()
	local win = state.wins.list
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if not M.in_himalaya_tab() then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	if buf == state.main then
		M.update_list_status()
		return
	end

	local render_state = state.email_state[buf]
	if render_state and render_state.env then
		vim.wo[win].winbar = winbar("Email · " .. (render_state.env.subject or "(no subject)"))
	else
		vim.wo[win].winbar = winbar("Emails")
	end
end

--- Shows a message in the folders winbar (used instead of a spinner).
function M.set_status(message)
	local win = state.wins.folders
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	local text = "Folders"
	if message and message ~= "" then
		text = text .. " · " .. message
	end
	vim.wo[win].winbar = winbar(text)
end

function M.show_buffer(buf)
	local win = state.wins.list
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	vim.api.nvim_win_set_buf(win, buf)
	M.update_active_winbar()
end

function M.show_list()
	M.show_buffer(state.main)
end

function M.resize_accounts(accounts)
	local win = state.wins.accounts
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	local height = math.max(3, math.min(#accounts + 1, config.config.accounts_height or 6))
	vim.api.nvim_win_set_height(win, height)
end

local function load_envelopes()
	if not (state.main and vim.api.nvim_buf_is_valid(state.main)) then
		return
	end

	local win = state.wins.list
	local height = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_height(win) or 20

	M.set_status("Loading emails")
	envelope_cli.list({
		mailbox = state.current_folder,
		page = state.current_page or 1,
		page_size = height,
		account = state.current_account,
	}, function(err, data)
		M.set_status(nil)
		if err then
			vim.notify("Failed to load emails: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		cache.set_envelopes(state.current_folder, state.current_page or 1, data)
		envelope_list.render(state.main, data)
		M.update_list_status()
	end)
end

local function on_folders_loaded(data)
	cache.set_folders(data)
	folder_list.render(state.sidebar, data)
	load_envelopes()
end

function M.load()
	local account = state.current_account

	account_list.load(state.accounts, function(err, accounts)
		if err then
			vim.notify("Failed to load accounts: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		M.resize_accounts(accounts or {})
	end)

	local cached_folders = cache.get_folders()
	if cached_folders then
		on_folders_loaded(cached_folders)
		folder_list.refresh_counts(account, state.sidebar)
		return
	end

	M.set_status("Loading")
	folder_cli.list({ account = account, counts = false }, function(err, data)
		M.set_status(nil)
		if err then
			vim.notify("Failed to load folders: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		on_folders_loaded(data)
		folder_list.refresh_counts(account, state.sidebar)
	end)
end

function M.cleanup_buffers()
	local seen = {}
	local function delete(buf)
		if not buf or seen[buf] then
			return
		end
		seen[buf] = true
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end

	delete(state.main)
	delete(state.sidebar)
	delete(state.accounts)
	delete(state.email)
	for _, buf in pairs(state.email_buffers) do
		delete(buf)
	end
end

function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("HimalayaWindows", { clear = true })

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(args)
			if state.closing then
				return
			end

			if args.buf == state.main then
				-- The list buffer is the anchor of the UI: closing it from the
				-- bufferline closes the whole tab.
				vim.schedule(function()
					M.close()
				end)
				return
			end

			if state.email_state[args.buf] then
				state.email_state[args.buf] = nil
				for id, buf in pairs(state.email_buffers) do
					if buf == args.buf then
						state.email_buffers[id] = nil
					end
				end
				if state.email == args.buf then
					state.email = nil
				end
				vim.schedule(function()
					if M.is_open() then
						M.show_list()
					end
				end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function()
			if state.closing then
				return
			end
			M.update_active_winbar()
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(args)
			if state.closing then
				return
			end
			local win = tonumber(args.match)
			if win == state.wins.list or win == state.wins.folders or win == state.wins.accounts then
				vim.schedule(function()
					if M.is_open() then
						M.close()
					end
				end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			if state.closing then
				return
			end
			if state.tab and not vim.api.nvim_tabpage_is_valid(state.tab) then
				state.closing = true
				M.cleanup_buffers()
				state.reset_ui()
				state.closing = false
			end
		end,
	})
end

function M.create()
	state.prev_tab = vim.api.nvim_get_current_tabpage()
	state.prev_win = vim.api.nvim_get_current_win()
	state.prev_buf = vim.api.nvim_get_current_buf()

	state.reset_ui()
	state.closing = false
	state.is_open = true

	vim.cmd("tabnew")
	local tab = vim.api.nvim_get_current_tabpage()
	state.tab = tab
	pcall(vim.api.nvim_tabpage_set_var, tab, "name", "Himalaya")

	local list_win = vim.api.nvim_get_current_win()
	local list_buf = M.create_buffer("Himalaya List", "himalaya-envelope-listing", true)
	vim.api.nvim_win_set_buf(list_win, list_buf)

	-- Left column: folders on top, accounts at the bottom.
	vim.cmd("topleft vsplit")
	local left_win = vim.api.nvim_get_current_win()
	vim.cmd("split")
	local folders_win = vim.api.nvim_get_current_win()
	local accounts_win = left_win

	local folders_buf = M.create_buffer("Himalaya folders", "himalaya-folder-listing", false)
	local accounts_buf = M.create_buffer("Himalaya accounts", "himalaya-account-listing", false)
	vim.api.nvim_win_set_buf(folders_win, folders_buf)
	vim.api.nvim_win_set_buf(accounts_win, accounts_buf)

	local sidebar_width = config.config.sidebar.width or 30
	vim.api.nvim_win_set_width(folders_win, sidebar_width)
	vim.api.nvim_win_set_width(accounts_win, sidebar_width)

	local accounts_height = math.max(3, math.min(8, config.config.accounts_height or 6))
	vim.api.nvim_win_set_height(accounts_win, accounts_height)

	set_win_opts(folders_win, { fix_width = true, fix_buf = true, winbar = winbar("Folders") })
	set_win_opts(accounts_win, { fix_width = true, fix_height = true, fix_buf = true, winbar = winbar("Accounts") })
	set_win_opts(list_win, { winbar = winbar("Emails") })

	state.wins = { folders = folders_win, accounts = accounts_win, list = list_win }
	state.sidebar = folders_buf
	state.accounts = accounts_buf
	state.main = list_buf
	state.email = nil

	M.setup_autocmds()
	vim.api.nvim_set_current_win(list_win)
	M.load()
end

function M.close()
	if state.closing then
		return
	end
	state.closing = true

	pcall(vim.api.nvim_del_augroup_by_name, "HimalayaWindows")

	local tab = state.tab
	local prev_tab = state.prev_tab
	local prev_buf = state.prev_buf
	local tabs = vim.api.nvim_list_tabpages()

	if tab and vim.api.nvim_tabpage_is_valid(tab) then
		if #tabs > 1 then
			local target = prev_tab
			if not (target and vim.api.nvim_tabpage_is_valid(target)) or target == tab then
				for _, t in ipairs(tabs) do
					if t ~= tab then
						target = t
						break
					end
				end
			end

			if target then
				pcall(vim.api.nvim_set_current_tabpage, target)
				pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(tab))
			end

			-- Fallback when tabclose refused: close the remaining windows.
			if vim.api.nvim_tabpage_is_valid(tab) then
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
					pcall(vim.api.nvim_win_close, win, true)
				end
			end
		else
			local list_win = state.wins.list
			if not (list_win and vim.api.nvim_win_is_valid(list_win)) then
				list_win = vim.api.nvim_get_current_win()
			end

			pcall(vim.api.nvim_set_current_win, list_win)
			if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
				pcall(vim.api.nvim_win_set_buf, list_win, prev_buf)
			else
				pcall(vim.cmd, "enew")
			end

			local current = vim.api.nvim_get_current_win()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if win ~= current then
					pcall(vim.api.nvim_win_close, win, true)
				end
			end
			set_win_opts(current, {})
		end
	end

	M.cleanup_buffers()
	state.reset_ui()
	state.closing = false
	state.prev_tab = nil
	state.prev_win = nil
	state.prev_buf = nil
end

return M
