local html = require("himalaya.html")

describe("HTML Bodies", function()
	local message = {
		text_body = { 1 },
		html_body = { 2 },
		parts = {
			{ body = { Multipart = {} } },
			{ body = { Text = "plain body" } },
			{ body = { Html = "<p>html body</p>" } },
		},
	}

	it("keeps the text body by default", function()
		local body = html.select(message, false)
		assert.truthy(body)
		assert.equals("text", body.kind)
		assert.equals("plain body", body.content)
	end)

	it("prefers the html body when asked", function()
		local body = html.select(message, true)
		assert.truthy(body)
		assert.equals("html", body.kind)
		assert.equals("<p>html body</p>", body.content)
	end)

	it("falls back to html when there is no text body", function()
		local body = html.select({
			html_body = { 1 },
			parts = { {}, { body = { Html = "<p>only html</p>" } } },
		}, false)
		assert.truthy(body)
		assert.equals("html", body.kind)
		assert.equals("<p>only html</p>", body.content)
	end)

	it("returns nil when there is no body", function()
		assert.is_nil(html.select({ parts = {} }, false))
		assert.is_nil(html.select(nil, false))
	end)
end)

describe("HTML preparation", function()
	it("strips image tags and picture blocks", function()
		local prepared = html.prepare([[<p>hello</p><img src="x.png" alt="x"><picture><source src="a"><img src="b"></picture><p>world</p>]])
		assert.falsy(prepared:find("<img", 1, true))
		assert.falsy(prepared:find("<picture", 1, true))
		assert.falsy(prepared:find("<source", 1, true))
		assert.contains(prepared, "hello")
		assert.contains(prepared, "world")
	end)
end)

describe("HTML Renderer Commands", function()
	it("builds a w3m command with the pane width", function()
		local cmd = html.command("w3m", 100, "/tmp/mail.html")
		assert.truthy(cmd)
		local str = table.concat(cmd, " ")
		assert.contains(str, "w3m -dump -T text/html")
		assert.contains(str, "-cols 100")
		assert.equals("/tmp/mail.html", cmd[#cmd])
	end)

	it("builds lynx and pandoc commands", function()
		local lynx = table.concat(html.command("lynx", 90, "/tmp/m.html"), " ")
		assert.contains(lynx, "-force_html")
		assert.contains(lynx, "-width 90")
		assert.contains(table.concat(html.command("pandoc", 90, "/tmp/m.html"), " "), "--columns 90")
	end)

	it("clamps tiny widths and rejects unknown renderers", function()
		local cmd = html.command("w3m", 5, "/tmp/m.html")
		assert.contains(table.concat(cmd, " "), "-cols 20")

		local bad, err = html.command("nope", 80, "/tmp/m.html")
		assert.is_nil(bad)
		assert.contains(err, "unknown HTML renderer")
	end)
end)
