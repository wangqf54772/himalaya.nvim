-- Mouse handling shared by every Himalaya buffer.
--
-- Neovim resolves a buffer-local <LeftMouse> mapping against the *current*
-- buffer, even when the click lands in another window. Mapping each Himalaya
-- buffer separately therefore made clicks in the sidebar run the listing's
-- mapping, which ignored them. A single dispatcher inspects the clicked window
-- and performs the matching action.
local state = require("himalaya.state")

local M = {}

local function replay_default_click(mouse)
	local buf = vim.api.nvim_get_current_buf()
	pcall(vim.keymap.del, "n", "<LeftMouse>", { buffer = buf })

	-- Re-send the click without the mapping so the tabline/statusline click
	-- regions (bufferline, lualine, tab indicators) handle it normally.
	local row = math.max(0, (mouse.screenrow or 1) - 1)
	local col = math.max(0, (mouse.screencol or 1) - 1)
	vim.api.nvim_input_mouse("left", "press", "", 0, row, col)

	vim.defer_fn(function()
		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].himalaya == true then
			M.attach(buf)
		end
	end, 30)
end

function M.click()
	local mouse = vim.fn.getmousepos()

	-- Tabline, winbar and statusline clicks report line 0 (and the window
	-- under the mouse). Replay them without this mapping so bufferline,
	-- lualine and tab indicators handle the click normally.
	if not mouse.line or mouse.line < 1 then
		replay_default_click(mouse)
		return
	end
	if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
		return
	end

	vim.api.nvim_set_current_win(mouse.winid)
	pcall(vim.api.nvim_win_set_cursor, mouse.winid, { mouse.line, 0 })

	local wins = state.wins or {}
	if mouse.winid == wins.folders then
		local name = state.folder_lines and state.folder_lines[mouse.line]
		if name then
			require("himalaya.folder").switch_to(name)
		end
	elseif mouse.winid == wins.accounts then
		local name = state.account_lines and state.account_lines[mouse.line]
		if name then
			require("himalaya.account").switch_to(name)
		end
	end
end

function M.attach(bufnr)
	vim.b[bufnr].himalaya = true
	vim.keymap.set("n", "<LeftMouse>", M.click, {
		buffer = bufnr,
		nowait = true,
		desc = "Himalaya click",
	})
end

return M
