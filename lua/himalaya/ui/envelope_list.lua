local NuiLine = require("nui.line")
local date_utils = require("himalaya.utils.date")
local state = require("himalaya.state")

local M = {}

local function has_flag(flags, target)
	if not flags then
		return false
	end
	target = target:lower()
	for _, f in ipairs(flags) do
		if type(f) == "table" then
			if f.iana and f.iana:lower() == target then
				return true
			end
			if f.raw and f.raw:lower():find(target, 1, true) then
				return true
			end
		elseif type(f) == "string" then
			if f:lower() == target or f:lower():find(target, 1, true) then
				return true
			end
		end
	end
	return false
end

-- Truncates text to at most `width` display cells without ever splitting a
-- character. Slicing bytes leaves invalid UTF-8, which Neovim renders as
-- replacement glyphs (a CJK character is 3 bytes but 2 cells wide).
local function truncate_width(text, width)
	if width <= 0 then
		return ""
	end
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end

	-- The width of a prefix grows with its character count, so binary search
	-- the longest prefix that fits instead of dropping one byte at a time.
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

function M.render(bufnr, envelopes)
	vim.bo[bufnr].modifiable = true
	vim.bo[bufnr].filetype = "himalaya-envelope-listing"

	state.current_envelopes = envelopes or {}

	-- Handle empty envelope list
	if not envelopes or #envelopes == 0 then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No emails in this mailbox" })
		vim.bo[bufnr].modifiable = false
		vim.bo[bufnr].modified = false
		state.current_envelope_count = 0
		return
	end

	-- Track envelope count
	state.current_envelope_count = #envelopes

	-- Use fixed max date width
	local max_date_width = date_utils.max_date_width()

	-- Get the width of the window actually showing the listing (fallback to 80)
	local win_width = 80
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		win = vim.api.nvim_get_current_win()
	end
	local ok, width = pcall(vim.api.nvim_win_get_width, win)
	if ok and width and width > 40 then
		win_width = width
	end

	local subject_width = win_width - 2 - 25 - max_date_width - 7
	if subject_width < 10 then
		subject_width = 10
	end

	-- Clear buffer first
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	local lines = {}

	for _, env in ipairs(envelopes) do
		local line = NuiLine()

		-- Flag indicator
		local is_seen = has_flag(env.flags, "seen")
		local is_flagged = has_flag(env.flags, "flagged")

		local flag_symbol = " "
		local flag_hl = "HimalayaFlag"

		if is_flagged then
			flag_symbol = "★"
			flag_hl = "HimalayaFlagged"
		elseif not is_seen then
			flag_symbol = "●"
			flag_hl = "HimalayaUnread"
		end
		line:append(flag_symbol .. " ", flag_hl)

		-- Attachment indicator
		local has_attachment = env["has-attachment"] or env.has_attachment
		if has_attachment then
			line:append("@ ", "HimalayaAttachment")
		else
			line:append("  ", "HimalayaAttachment")
		end

		-- From - handle v2 array of Address objects or fallback
		local from = "Unknown"
		if env.from then
			local sender = type(env.from) == "table" and (env.from[1] or env.from) or {}
			from = sender.name or sender.email or sender.addr or "Unknown"
		end
		local from_display = truncate_width(from, 23)
		local from_padding = 23 - vim.fn.strdisplaywidth(from_display)
		if from_padding < 0 then
			from_padding = 0
		end
		line:append(from_display .. string.rep(" ", from_padding) .. " ", "HimalayaFrom")

		-- Subject - truncate based on display width, keeping whole characters
		local subject = env.subject or "(no subject)"
		local subject_display = subject

		if vim.fn.strdisplaywidth(subject_display) > subject_width then
			subject_display = truncate_width(subject, subject_width - 3) .. "..."
		end

		local padding = subject_width + 1 - vim.fn.strdisplaywidth(subject_display)
		if padding < 0 then
			padding = 0
		end
		line:append(subject_display .. string.rep(" ", padding), "HimalayaSubject")

		-- Date (relative)
		local relative = date_utils.relative_date(env.date)
		line:append("(" .. relative .. ")", "HimalayaDate")

		table.insert(lines, line)
	end

	for i, line in ipairs(lines) do
		line:render(bufnr, -1, i)
	end

	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].modified = false
end

return M
