local NuiLine = require("nui.line")
local state = require("himalaya.state")
local account_cli = require("himalaya.cli.account")

local M = {}

--- Renders the accounts section of the sidebar.
---@param bufnr integer
---@param accounts table[]
---@param current string|nil
function M.render(bufnr, accounts, current)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.bo[bufnr].modifiable = true
	vim.bo[bufnr].filetype = "himalaya-account-listing"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	state.account_lines = {}
	local lines = {}
	local active_line = nil

	for i, account in ipairs(accounts or {}) do
		local name = account.name or ("account " .. i)
		local is_current = (current ~= nil and current ~= "" and current == name)
			or ((current == nil or current == "") and account.default == true)

		local line = NuiLine()
		if is_current then
			active_line = i
		end
		line:append(" " .. name, is_current and "HimalayaAccountActive" or "HimalayaAccount")
		if account.default then
			line:append(" (default)", "HimalayaAccountDefault")
		end

		table.insert(lines, line)
		state.account_lines[i] = name
	end

	if #lines == 0 then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { " No accounts" })
	else
		for i, line in ipairs(lines) do
			line:render(bufnr, -1, i)
		end
	end

	-- Keep the cursor on the active account (re-rendering clears the buffer).
	if active_line then
		for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
			pcall(vim.api.nvim_win_set_cursor, win, { active_line, 0 })
		end
	end

	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].modified = false
end

--- Fetches the account list and renders it.
function M.load(bufnr, callback)
	account_cli.list({}, function(err, accounts)
		if err then
			if callback then
				callback(err, nil)
			end
			return
		end

		require("himalaya.cache").set_accounts(accounts)
		M.render(bufnr, accounts, state.current_account)
		if callback then
			callback(nil, accounts)
		end
	end)
end

--- Re-renders from the cached account list (used after switching accounts).
function M.refresh(bufnr)
	local cache = require("himalaya.cache")
	M.render(bufnr, cache.get_accounts() or {}, state.current_account)
end

return M
