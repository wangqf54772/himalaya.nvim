local state = require("himalaya.state")
local email = require("himalaya.email")
local config = require("himalaya.config")
local html = require("himalaya.html")
local runner = require("himalaya.cli.runner")
local Popup = require("nui.popup")
local Layout = require("nui.layout")

describe("UI Email HTML rendering", function()
	local sidebar_popup, main_popup, email_popup, layout
	local original_render, original_render_html, original_prefer_html

	local payload = {
		text_body = { 1 },
		html_body = { 2 },
		parts = {
			{ body = { Multipart = {} } },
			{ body = { Text = "plain body" } },
			{ body = { Html = "<p>rich body</p>" } },
		},
	}

	before_each(function()
		sidebar_popup = Popup({ enter = false })
		main_popup = Popup({ enter = true })
		email_popup = Popup({ enter = false })

		layout = Layout({
			position = "50%",
			size = { width = "90%", height = "90%" },
		}, Layout.Box({
			Layout.Box(sidebar_popup, { size = 30 }),
			Layout.Box(main_popup, { grow = 1 }),
		}, { dir = "row" }))

		state.sidebar = sidebar_popup.bufnr
		state.sidebar_popup = sidebar_popup
		state.main = main_popup.bufnr
		state.main_popup = main_popup
		state.email = email_popup.bufnr
		state.email_popup = email_popup
		state.layout = layout
		state.email_visible = false
		state.current_folder = "INBOX"
		state.current_account = ""
		state.current_envelopes = {
			{
				id = "101",
				flags = {},
				from = { { name = "Alice", email = "alice@example.com" } },
				to = { { email = "bob@example.com" } },
				subject = "Hello",
				date = "2026-09-03T01:10:53Z",
			},
		}

		original_render = html.render
		original_render_html = config.config.render_html
		original_prefer_html = config.config.prefer_html
	end)

	after_each(function()
		runner.reset_mock()
		html.render = original_render
		config.config.render_html = original_render_html
		config.config.prefer_html = original_prefer_html
	end)

	local function mock_message(payload_table, executed)
		runner.set_mock(function(cmd, callback)
			if executed then
				executed.cmd = cmd
			end
			callback(nil, vim.json.encode(payload_table))
		end)
	end

	it("fetches JSON and renders the HTML body when enabled", function()
		config.config.render_html = true
		config.config.prefer_html = true
		local executed = {}
		mock_message(payload, executed)

		local rendered_args = nil
		html.render = function(content, renderer, width, callback)
			rendered_args = { content = content, renderer = renderer, width = width }
			callback(nil, "RENDERED BODY")
		end

		email.open()

		assert.truthy(executed.cmd)
		local cmd_str = table.concat(executed.cmd, " ")
		assert.contains(cmd_str, "message read")
		assert.contains(cmd_str, "--json")
		assert.equals("<p>rich body</p>", rendered_args.content)
		assert.equals("w3m", rendered_args.renderer)

		local lines = vim.api.nvim_buf_get_lines(state.email, 0, -1, false)
		local text = table.concat(lines, "\n")
		assert.contains(text, "Subject: Hello")
		assert.contains(text, "From: Alice <alice@example.com>")
		assert.contains(text, "RENDERED BODY")
		assert.falsy(text:find("<p>rich body</p>", 1, true), "raw markup must not be shown")
	end)

	it("keeps the text body when prefer_html is off", function()
		config.config.render_html = true
		config.config.prefer_html = false
		mock_message(payload, nil)

		local render_called = false
		html.render = function(_, _, _, callback)
			render_called = true
			callback(nil, "RENDERED BODY")
		end

		email.open()

		local text = table.concat(vim.api.nvim_buf_get_lines(state.email, 0, -1, false), "\n")
		assert.falsy(render_called, "text body must not go through the HTML renderer")
		assert.contains(text, "plain body")
	end)

	it("falls back to the HTML source when rendering fails", function()
		config.config.render_html = true
		config.config.prefer_html = true
		mock_message(payload, nil)

		html.render = function(_, _, _, callback)
			callback("renderer exploded", nil)
		end

		email.open()

		local text = table.concat(vim.api.nvim_buf_get_lines(state.email, 0, -1, false), "\n")
		assert.contains(text, "<p>rich body</p>")
	end)

	it("toggles between rendered HTML and its source", function()
		config.config.render_html = true
		config.config.prefer_html = true
		mock_message(payload, nil)
		html.render = function(_, _, _, callback)
			callback(nil, "RENDERED BODY")
		end

		email.open()
		assert.contains(table.concat(vim.api.nvim_buf_get_lines(state.email, 0, -1, false), "\n"), "RENDERED BODY")

		email.toggle_html()
		local raw = table.concat(vim.api.nvim_buf_get_lines(state.email, 0, -1, false), "\n")
		assert.contains(raw, "<p>rich body</p>")
		assert.falsy(raw:find("RENDERED BODY", 1, true))

		email.toggle_html()
		local rendered = table.concat(vim.api.nvim_buf_get_lines(state.email, 0, -1, false), "\n")
		assert.contains(rendered, "RENDERED BODY")
	end)
end)
