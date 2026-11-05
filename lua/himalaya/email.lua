local state = require("himalaya.state")
local Layout = require("nui.layout")
local config = require("himalaya.config")
local message_cli = require("himalaya.cli.message")
local html = require("himalaya.html")

local M = {}

-- Kept for the raw/rendered toggle (`gH`), reset on every open.
local current = {
	env = nil,
	folder = nil,
	raw_html = nil,
	rendered = nil,
	showing_raw = false,
}

function M.get_selected_envelope()
	if not state.main or not state.current_envelopes then
		return nil
	end

	local win = vim.fn.bufwinid(state.main)
	local linenr = 1
	if win ~= -1 then
		linenr = vim.api.nvim_win_get_cursor(win)[1]
	end

	return state.current_envelopes[linenr]
end

local function pane_width()
	local win = state.email and vim.fn.bufwinid(state.email) or -1
	if win ~= -1 then
		local width = vim.api.nvim_win_get_width(win)
		if width and width > 20 then
			return width
		end
	end
	return 80
end

local function format_addresses(addresses)
	local out = {}
	for _, address in ipairs(addresses or {}) do
		if type(address) == "table" then
			if address.name and address.name ~= "" then
				table.insert(out, ("%s <%s>"):format(address.name, address.email or ""))
			elseif address.email then
				table.insert(out, address.email)
			end
		elseif type(address) == "string" then
			table.insert(out, address)
		end
	end
	return table.concat(out, ", ")
end

local function header_lines(env)
	return {
		"From: " .. format_addresses(env.from),
		"To: " .. format_addresses(env.to),
		"Subject: " .. (env.subject or "(no subject)"),
		"Date: " .. (env.date or ""),
		"",
	}
end

local function set_email_lines(lines)
	vim.bo[state.email].modifiable = true
	vim.api.nvim_buf_set_lines(state.email, 0, -1, false, lines)
	vim.bo[state.email].modifiable = false
	vim.bo[state.email].modified = false
end

-- Shows a rendered body under a compact header taken from the envelope. The
-- CLI plain output is only used when HTML rendering is disabled, since it
-- cannot show a rendered HTML body.
local function show_body(env, content)
	local lines = header_lines(env)
	local clean = (content or ""):gsub("\r\n", "\n"):gsub("\r", "")
	if clean ~= "" then
		vim.list_extend(lines, vim.split(clean, "\n", { plain = true }))
	end
	set_email_lines(lines)
end

local function mark_seen(env)
	local has_seen = false
	for _, f in ipairs(env.flags or {}) do
		if (type(f) == "table" and f.iana == "seen") or f == "seen" then
			has_seen = true
			break
		end
	end

	if has_seen then
		return
	end

	table.insert(env.flags, { iana = "seen", raw = "\\Seen" })
	require("himalaya.ui.envelope_list").render(state.main, state.current_envelopes)

	local cache = require("himalaya.cache")
	cache.adjust_folder_unread(state.current_folder, -1)
	if state.sidebar and cache.get_folders() then
		require("himalaya.ui.folder_list").render(state.sidebar, cache.get_folders())
	end
end

local function show_error(err)
	if not state.email or not vim.api.nvim_buf_is_valid(state.email) then
		return
	end
	vim.bo[state.email].modifiable = true
	vim.api.nvim_buf_set_lines(state.email, 0, -1, false, { "Error loading email: " .. tostring(err) })
	vim.bo[state.email].modifiable = false
end

-- Reads the message as the CLI's parsed JSON, which carries the decoded text
-- and HTML bodies (`text_body` / `html_body` are indexes into `parts`).
local function open_rich(env, folder, account)
	message_cli.read({
		id = env.id,
		mailbox = folder,
		account = account,
		seen = true,
		json = true,
	}, function(err, message)
		if not state.email or not vim.api.nvim_buf_is_valid(state.email) then
			return
		end
		if err then
			show_error(err)
			return
		end

		local body = html.select(message, config.config.prefer_html)
		if not body then
			show_body(env, "(no text body)")
		elseif body.kind == "text" then
			show_body(env, body.content)
		else
			current.raw_html = body.content
			local placeholder = header_lines(env)
			table.insert(placeholder, "Rendering HTML...")
			set_email_lines(placeholder)

			html.render(body.content, config.config.html_renderer, pane_width(), function(render_err, rendered)
				if state.selected_email_id ~= env.id or state.current_folder ~= folder then
					return
				end
				if not state.email or not vim.api.nvim_buf_is_valid(state.email) then
					return
				end

				if render_err or not rendered then
					vim.notify(
						("HTML render failed: %s (showing source)"):format(tostring(render_err)),
						vim.log.levels.WARN
					)
					show_body(env, body.content)
					return
				end

				current.rendered = rendered
				show_body(env, rendered)
			end)
		end

		mark_seen(env)
	end)
end

local function open_plain(env, folder, account)
	message_cli.read({
		id = env.id,
		mailbox = folder,
		account = account,
		seen = true,
	}, function(err, content)
		if not state.email or not vim.api.nvim_buf_is_valid(state.email) then
			return
		end
		if err then
			show_error(err)
			return
		end

		local clean = (content or ""):gsub("\r\n", "\n"):gsub("\r", "")
		if clean:sub(-1) == "\n" then
			clean = clean:sub(1, -2)
		end
		set_email_lines(vim.split(clean, "\n", { plain = true }))
		mark_seen(env)
	end)
end

function M.open()
	if not state.layout or not state.main_popup or not state.sidebar_popup or not state.email_popup then
		return
	end

	local env = M.get_selected_envelope()
	if not env or not env.id then
		return
	end

	state.selected_email_id = env.id
	local folder = state.current_folder
	local account = state.current_account

	current.env = env
	current.folder = folder
	current.raw_html = nil
	current.rendered = nil
	current.showing_raw = false

	-- If already open, just focus it
	local email_win_valid = state.email_popup.winid and vim.api.nvim_win_is_valid(state.email_popup.winid)
	if not state.email_visible or not email_win_valid then
		state.layout:update(Layout.Box({
			Layout.Box(state.sidebar_popup, { size = config.config.sidebar.width }),
			Layout.Box({
				Layout.Box(state.main_popup, { size = "50%" }),
				Layout.Box(state.email_popup, { grow = 1 }),
			}, { dir = "col", grow = 1 }),
		}, { dir = "row" }))
		state.email_visible = true
	end

	-- Focus email window
	vim.schedule(function()
		if state.email and vim.api.nvim_buf_is_valid(state.email) then
			local email_win = vim.fn.bufwinid(state.email)
			if email_win ~= -1 then
				vim.api.nvim_set_current_win(email_win)
			end
		end
	end)

	vim.bo[state.email].modifiable = true
	vim.bo[state.email].filetype = "himalaya-email"
	vim.api.nvim_buf_set_lines(state.email, 0, -1, false, { "Loading email " .. env.id .. "..." })

	if config.config.render_html then
		open_rich(env, folder, account)
	else
		open_plain(env, folder, account)
	end
end

--- Toggles the reader pane between the rendered HTML and its source.
function M.toggle_html()
	if not current.env then
		return
	end
	if not current.raw_html then
		vim.notify("This message has no HTML body (enable render_html to render them)", vim.log.levels.WARN)
		return
	end
	if not current.rendered then
		vim.notify("HTML body is still rendering", vim.log.levels.WARN)
		return
	end

	current.showing_raw = not current.showing_raw
	local content = current.showing_raw and current.raw_html or current.rendered
	show_body(current.env, content)

	local win = state.email and vim.fn.bufwinid(state.email) or -1
	if win ~= -1 then
		pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
	end
end

function M.close()
	if not state.layout or not state.email_visible then
		return
	end

	-- Update layout to hide email popup
	state.layout:update(Layout.Box({
		Layout.Box(state.sidebar_popup, { size = config.config.sidebar.width }),
		Layout.Box(state.main_popup, { grow = 1 }),
	}, { dir = "row" }))

	state.email_visible = false

	-- Realign main window content to fill the space
	vim.schedule(function()
		if state.main and vim.api.nvim_buf_is_valid(state.main) then
			local main_win = vim.fn.bufwinid(state.main)
			if main_win ~= -1 then
				vim.api.nvim_set_current_win(main_win)
				local cursor = vim.api.nvim_win_get_cursor(main_win)
				vim.cmd("normal! gg")
				vim.api.nvim_win_set_cursor(main_win, cursor)
			end
		end
	end)
end

return M
