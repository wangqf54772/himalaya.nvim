local config = require("himalaya.config")
local state = require("himalaya.state")
local windows = require("himalaya.ui.windows")

local M = {}

function M.setup(opts)
	config.setup(opts)
end

function M.open()
	if windows.is_open() then
		pcall(vim.api.nvim_set_current_tabpage, state.tab)
		vim.notify("Himalaya is already open", vim.log.levels.INFO)
		return
	end

	windows.create()
end

function M.close()
	windows.close()
end

return M
