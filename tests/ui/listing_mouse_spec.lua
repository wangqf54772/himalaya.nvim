describe("Listing mouse mappings", function()
	it("selects on single click and opens on double click", function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
		dofile(root .. "/ftplugin/himalaya-envelope-listing.lua")

		local single, double = nil, nil
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
			if map.lhs == "<LeftMouse>" then
				single = map
			elseif map.lhs == "<2-LeftMouse>" then
				double = map
			end
		end

		assert.truthy(single, "expected a single-click mapping")
		assert.truthy(double, "expected a double-click mapping")
		assert.equals("Select email", single.desc)
		assert.equals("Open email", double.desc)

		vim.api.nvim_buf_delete(buf, { force = true })
	end)
end)
