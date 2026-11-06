local state = require("himalaya.state")
local config = require("himalaya.config")
local message_cli = require("himalaya.cli.message")
local html = require("himalaya.html")
local windows = require("himalaya.ui.windows")

local M = {}

local function truncate_width(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	local lo, hi = 0, vim.fn.strchars(text)
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, mid)) <= width then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return vim.fn.strcharpart(text, 0, lo)
end

local function reader_name(env)
	return "Himalaya: " .. truncate_width(env.subject or "(no subject)", 40)
end

function M.get_selected_envelope()
	-- When a reader is shown, the listing buffer is hidden, so the cursor
	-- cannot be used: the open message is the selected one.
	local reader_win = state.wins and state.wins.list
	if reader_win and vim.api.nvim_win_is_valid(reader_win) then
		local reader_buf = vim.api.nvim_win_get_buf(reader_win)
		local render_state = state.email_state[reader_buf]
		if render_state and render_state.env then
			return render_state.env
		end
	end

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
	local win = state.wins.list
	if win and vim.api.nvim_win_is_valid(win) then
		return vim.api.nvim_win_get_width(win)
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

local function set_buffer_lines(buf, lines)
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
end

local function show_body(buf, env, content)
	local lines = header_lines(env)
	local clean = (content or ""):gsub("\r\n", "\n"):gsub("\r", "")
	if clean ~= "" then
		vim.list_extend(lines, vim.split(clean, "\n", { plain = true }))
	end
	set_buffer_lines(buf, lines)
	windows.update_active_winbar()
end

local function show_placeholder(buf, env, message)
	local lines = header_lines(env)
	table.insert(lines, message)
	set_buffer_lines(buf, lines)
	windows.update_active_winbar()
end

local function show_error(buf, err)
	set_buffer_lines(buf, { "Error loading email: " .. tostring(err) })
end

local function mark_seen(env)
	if not (state.main and vim.api.nvim_buf_is_valid(state.main)) then
		return
	end

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
	if state.sidebar and vim.api.nvim_buf_is_valid(state.sidebar) and cache.get_folders() then
		require("himalaya.ui.folder_list").render(state.sidebar, cache.get_folders())
	end
end

local function open_rich(env, folder, account, buf)
	message_cli.read({
		id = env.id,
		mailbox = folder,
		account = account,
		seen = true,
		json = true,
	}, function(err, message)
		if not (buf and vim.api.nvim_buf_is_valid(buf)) or state.email_buffers[env.id] ~= buf then
			return
		end
		if err then
			show_error(buf, err)
			return
		end

		local render_state = state.email_state[buf]
		if not render_state then
			return
		end

		local body = html.select(message, config.config.prefer_html)
		if not body then
			show_body(buf, env, "(no text body)")
		elseif body.kind == "text" then
			show_body(buf, env, body.content)
		else
			render_state.raw_html = body.content
			show_placeholder(buf, env, "Rendering HTML...")

			html.render(body.content, config.config.html_renderer, pane_width(), function(render_err, rendered)
				if not (buf and vim.api.nvim_buf_is_valid(buf)) or state.email_buffers[env.id] ~= buf then
					return
				end
				if render_err or not rendered then
					vim.notify(
						("HTML render failed: %s (showing source)"):format(tostring(render_err)),
						vim.log.levels.WARN
					)
					show_body(buf, env, body.content)
					return
				end

				render_state.rendered = rendered
				show_body(buf, env, rendered)
			end)
		end

		mark_seen(env)
	end)
end

local function open_plain(env, folder, account, buf)
	message_cli.read({
		id = env.id,
		mailbox = folder,
		account = account,
		seen = true,
	}, function(err, content)
		if not (buf and vim.api.nvim_buf_is_valid(buf)) or state.email_buffers[env.id] ~= buf then
			return
		end
		if err then
			show_error(buf, err)
			return
		end

		local clean = (content or ""):gsub("\r\n", "\n"):gsub("\r", "")
		if clean:sub(-1) == "\n" then
			clean = clean:sub(1, -2)
		end
		set_buffer_lines(buf, vim.split(clean, "\n", { plain = true }))
		windows.update_active_winbar()
		mark_seen(env)
	end)
end

function M.open()
	if not windows.is_open() then
		return
	end

	local env = M.get_selected_envelope()
	if not env or not env.id then
		return
	end

	local folder = state.current_folder
	local account = state.current_account

	local buf = state.email_buffers[env.id]
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		buf = windows.create_buffer(reader_name(env), "himalaya-email", true)
		state.email_buffers[env.id] = buf
	end

	state.email = buf
	state.selected_email_id = env.id
	state.email_state[buf] = {
		env = env,
		folder = folder,
		raw_html = nil,
		rendered = nil,
		showing_raw = false,
	}

	windows.show_buffer(buf)
	windows.focus_list()
	show_placeholder(buf, env, "Loading email " .. env.id .. "...")

	if config.config.render_html then
		open_rich(env, folder, account, buf)
	else
		open_plain(env, folder, account, buf)
	end
end

--- Closes the reader currently shown in the right window.
function M.close()
	local win = state.wins.list
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	if buf == state.main then
		return
	end

	windows.show_list()
	if buf and vim.api.nvim_buf_is_valid(buf) and state.email_state[buf] then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	state.email = nil
end

--- Closes one reader buffer from the bufferline, switching the reader window
--- back to the list first so `:bdelete` does not close that window.
function M.close_buffer(bufnr)
	local render_state = state.email_state[bufnr]
	if not render_state then
		return false
	end

	local win = state.wins.list
	if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
		windows.show_list()
	end

	state.email_state[bufnr] = nil
	for id, buf in pairs(state.email_buffers) do
		if buf == bufnr then
			state.email_buffers[id] = nil
		end
	end
	if state.email == bufnr then
		state.email = nil
	end

	if vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end
	return true
end

--- Closes every open reader buffer (used when switching accounts).
function M.close_all()
	windows.show_list()
	for _, buf in pairs(state.email_buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	state.email_buffers = {}
	state.email_state = {}
	state.email = nil
end

--- Toggles the reader between the rendered HTML and its source.
function M.toggle_html(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local render_state = state.email_state[bufnr]
	if not render_state then
		vim.notify("This message has no HTML body (enable render_html to render them)", vim.log.levels.WARN)
		return
	end
	if not render_state.raw_html then
		vim.notify("This message has no HTML body (enable render_html to render them)", vim.log.levels.WARN)
		return
	end
	if not render_state.rendered then
		vim.notify("HTML body is still rendering", vim.log.levels.WARN)
		return
	end

	render_state.showing_raw = not render_state.showing_raw
	local content = render_state.showing_raw and render_state.raw_html or render_state.rendered
	show_body(bufnr, render_state.env, content)
end

return M
