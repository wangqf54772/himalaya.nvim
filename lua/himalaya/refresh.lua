-- Periodic and focus-driven refresh.
--
-- The plugin has no background sync of its own: every refresh is one CLI call.
-- This module schedules them:
--
--   * a timer that fires `refresh_interval` seconds after the last query, so
--     any manual reload (R, folder/account switch, page change, search) pushes
--     the next automatic refresh back;
--   * a refresh when Neovim regains focus, debounced so alt-tabbing does not
--     hammer the server.
--
-- Both are no-ops unless the Himalaya tabpage is open, and the timer only fires
-- while it is the current tabpage with a visible UI.
local state = require("himalaya.state")
local config = require("himalaya.config")

local M = {}

local function enabled()
	return config.config.refresh_interval and config.config.refresh_interval > 0
end

local function ui_ready()
	if not state.is_open or not state.tab then
		return false
	end
	if not vim.api.nvim_tabpage_is_valid(state.tab) then
		return false
	end
	if vim.api.nvim_get_current_tabpage() ~= state.tab then
		return false
	end
	local wins = state.wins or {}
	for _, win in ipairs({ wins.folders, wins.accounts, wins.list }) do
		if not win or not vim.api.nvim_win_is_valid(win) then
			return false
		end
	end
	return true
end

local function stop_timer()
	if state.refresh_timer then
		pcall(function()
			state.refresh_timer:stop()
		end)
		pcall(function()
			state.refresh_timer:close()
		end)
		state.refresh_timer = nil
	end
end

--- Runs one refresh of the current account, mailbox and page.
---@param opts { notify: boolean|nil }|nil
function M.refresh(opts)
	opts = opts or {}
	if not ui_ready() then
		return
	end

	local windows = require("himalaya.ui.windows")
	if state.refreshing then
		return
	end
	state.refreshing = true
	state.refresh_last = (vim.uv or vim.loop).now()

	require("himalaya.folder").reload(function(err)
		state.refreshing = false
		if err then
			if opts.notify then
				vim.notify("Refresh failed: " .. tostring(err), vim.log.levels.WARN)
			end
			return
		end
		-- Any query restarts the countdown.
		M.schedule()
	end)
end

--- Restarts the countdown to the next automatic refresh.
function M.schedule()
	stop_timer()

	if not enabled() or not ui_ready() then
		return
	end

	local loop = vim.uv or vim.loop
	state.refresh_timer = loop.new_timer()
	state.refresh_timer:start(
		math.floor(config.config.refresh_interval * 1000),
		0,
		vim.schedule_wrap(function()
			stop_timer()
			if not ui_ready() then
				return
			end
			M.refresh({ notify = false })
		end)
	)
end

--- Called whenever the plugin performs a query, so the timer starts over.
function M.touch()
	if not state.is_open then
		return
	end
	M.schedule()
end

function M.stop()
	stop_timer()
	state.refreshing = false
end

--- Installs the focus autocmds. Safe to call once per UI creation.
function M.setup()
	local group = vim.api.nvim_create_augroup("HimalayaRefresh", { clear = true })

	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			if not ui_ready() or state.refreshing then
				return
			end

			-- Debounce: ignore focus events that arrive right after a refresh.
			local now = (vim.uv or vim.loop).now()
			local debounce = (config.config.refresh_focus_debounce or 0) * 1e9
			if state.refresh_last and (now - state.refresh_last) < debounce then
				return
			end

			M.refresh({ notify = false })
		end,
	})

	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			if not ui_ready() then
				return
			end
			M.refresh({ notify = false })
		end,
	})
end

function M.teardown()
	pcall(vim.api.nvim_del_augroup_by_name, "HimalayaRefresh")
	stop_timer()
	state.refreshing = false
	state.refresh_last = nil
end

return M
