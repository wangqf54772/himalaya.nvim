local envelope_list = require("himalaya.ui.envelope_list")
local state = require("himalaya.state")

-- Invalid UTF-8 does not round-trip through str2list/list2str: broken bytes are
-- read as Latin-1 code points and re-encoded as two bytes.
local function is_valid_utf8(str)
	return vim.fn.list2str(vim.fn.str2list(str)) == str
end

describe("UI Envelope List", function()
	it("renders v2 envelopes with structured from and flags", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		local test_envelopes = {
			{
				id = "101",
				subject = "Unread Message",
				from = { { name = "Alice Smith", email = "alice@example.com" } },
				flags = {},
				date = "2026-09-03T01:10:53Z",
				["has-attachment"] = false,
			},
			{
				id = "102",
				subject = "Seen and Flagged",
				from = { { name = nil, email = "bob@example.com" } },
				flags = {
					{ iana = "seen", raw = "\\Seen" },
					{ iana = "flagged", raw = "\\Flagged" },
				},
				date = "2026-09-02T10:00:00Z",
				["has-attachment"] = true,
			},
		}

		envelope_list.render(bufnr, test_envelopes)

		assert.equals(2, state.current_envelope_count)
		assert.same(test_envelopes, state.current_envelopes)

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.equals(2, #lines)

		-- Line 1 should have Alice Smith and Unread Message
		assert.contains(lines[1], "Alice Smith")
		assert.contains(lines[1], "Unread Message")
		assert.contains(lines[1], "●")

		-- Line 2 should have bob@example.com and Seen and Flagged
		assert.contains(lines[2], "bob@example.com")
		assert.contains(lines[2], "Seen and Flagged")
		assert.contains(lines[2], "★")

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("truncates CJK sender and subject without splitting characters", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		envelope_list.render(bufnr, {
			{
				id = "201",
				subject = "这是一封用来测试中文主题截断是否安全的非常长的邮件主题",
				from = { { name = "网易邮箱账号安全中心客服组", email = "safe@example.com" } },
				flags = {},
				date = "2026-09-03T01:10:53+08:00",
				["has-attachment"] = false,
			},
		})

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.equals(1, #lines)
		assert.truthy(is_valid_utf8(lines[1]), "rendered line must stay valid UTF-8")

		-- The sender keeps whole characters only: 11 CJK characters fit in 23 cells.
		assert.contains(lines[1], "网易邮箱账号安全中心客")
		assert.falsy(lines[1]:find("服", 1, true), "sender must not keep a partial tail")

		-- The subject is cut short and marked as truncated.
		assert.contains(lines[1], "...")
		assert.falsy(lines[1]:find("非常长的邮件主题", 1, true), "subject must not keep its tail")

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)
