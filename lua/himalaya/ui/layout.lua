-- Compatibility facade over the native window UI.
--
-- folder/page/actions used to call the nui layout helpers directly. They now
-- drive the winbar status of the native windows, keeping the call sites small.
local windows = require("himalaya.ui.windows")

local M = {}

function M.create()
	windows.create()
end

function M.show_spinner(message)
	windows.set_status(message)
end

function M.hide_spinner()
	windows.set_status(nil)
end

function M.update_page_footer()
	windows.update_list_status()
end

return M
