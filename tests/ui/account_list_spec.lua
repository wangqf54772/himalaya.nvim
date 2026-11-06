local account_list = require("himalaya.ui.account_list")
local state = require("himalaya.state")

describe("Account list", function()
	it("renders names, the default marker and the line map", function()
		local buf = vim.api.nvim_create_buf(false, true)
		state.current_account = "jlu"

		account_list.render(buf, {
			{ name = "163", default = true },
			{ name = "jlu", default = false },
			{ name = "qq", default = false },
		}, "jlu")

		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert.equals(3, #lines)
		assert.contains(lines[1], "163")
		assert.contains(lines[1], "(default)")
		assert.equals("163", state.account_lines[1])
		assert.equals("jlu", state.account_lines[2])
		assert.equals("qq", state.account_lines[3])
		assert.equals("himalaya-account-listing", vim.bo[buf].filetype)
		assert.falsy(vim.bo[buf].modifiable)

		vim.api.nvim_buf_delete(buf, { force = true })
	end)
end)
