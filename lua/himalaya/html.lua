local runner = require("himalaya.cli.runner")

local M = {}

-- Renderers take a local HTML file and print plain text on stdout. `width` is
-- the number of terminal columns the reader pane can show.
local builders = {
	w3m = function(width, path)
		return { "w3m", "-dump", "-T", "text/html", "-I", "UTF-8", "-cols", tostring(width), path }
	end,
	lynx = function(width, path)
		return {
			"lynx",
			"-dump",
			"-force_html",
			"-width",
			tostring(width),
			"-assume_charset=UTF-8",
			"-display_charset=UTF-8",
			path,
		}
	end,
	pandoc = function(width, path)
		return {
			"pandoc",
			"-f",
			"html",
			"-t",
			"plain",
			"--wrap=auto",
			"--columns",
			tostring(width),
			path,
		}
	end,
}

--- Builds the renderer command for the given renderer name and pane width.
---@param renderer string|nil
---@param width number|nil
---@param path string
---@return string[]|nil cmd
---@return string|nil err
function M.command(renderer, width, path)
	renderer = renderer or "w3m"
	local build = builders[renderer]
	if not build then
		return nil, ("unknown HTML renderer %q (expected w3m, lynx or pandoc)"):format(tostring(renderer))
	end

	width = tonumber(width) or 80
	if width < 20 then
		width = 20
	end
	return build(width, path)
end

--- Picks the body to display from a `message read --json` payload.
---
--- The CLI reports the text and HTML bodies as zero-based positions into the
--- JSON `parts` array, while Lua tables are 1-based: `text_body = { 1 }` means
--- `parts[2].body.Text`.
---@param message table
---@param prefer_html boolean|nil
---@return table|nil body `{ kind = "text"|"html", content = string }`
function M.select(message, prefer_html)
	if type(message) ~= "table" then
		return nil
	end

	local function content_at(index, kind)
		local part = type(index) == "number" and message.parts and message.parts[index + 1]
		local body = type(part) == "table" and part.body
		local content = type(body) == "table" and body[kind]
		if type(content) == "string" and content ~= "" then
			return content
		end
		return nil
	end

	local text = content_at(message.text_body and message.text_body[1], "Text")
	local html = content_at(message.html_body and message.html_body[1], "Html")

	if prefer_html and html then
		return { kind = "html", content = html }
	end
	if text then
		return { kind = "text", content = text }
	end
	if html then
		return { kind = "html", content = html }
	end
	return nil
end

--- Removes image tags before rendering.
---
--- Terminal renderers cannot show them, and w3m prints a noisy `[filename]`
--- placeholder for every image, which clutters marketing emails.
---@param source string
---@return string
function M.prepare(source)
	source = source:gsub("<%s*[Ii][Mm][Gg][^>]*>", "")
	source = source:gsub(
		"<%s*[Pp][Ii][Cc][Tt][Uu][Rr][Ee][^>]*>.-</%s*[Pp][Ii][Cc][Tt][Uu][Rr][Ee]%s*>",
		""
	)
	return source
end

--- Renders an HTML body to plain text through the configured renderer.
---
--- The HTML goes through a private temporary file instead of stdin: email
--- bodies can outgrow a single pipe write, and every renderer accepts a path.
---@param html string
---@param renderer string|nil
---@param width number|nil
---@param callback fun(err: string|nil, rendered: string|nil)
function M.render(html, renderer, width, callback)
	html = M.prepare(html)
	local path = vim.fn.tempname()
	local cmd, err = M.command(renderer, width, path)
	if not cmd then
		callback(err, nil)
		return
	end

	if vim.fn.executable(cmd[1]) ~= 1 then
		callback(("HTML renderer not found: %s"):format(cmd[1]), nil)
		return
	end

	local written = vim.fn.writefile(vim.split(html, "\n", { plain = true }), path)
	if written ~= 0 then
		callback(("cannot write temporary HTML file %s"):format(path), nil)
		return
	end
	pcall((vim.uv or vim.loop).fs_chmod, path, 384)

	runner.run(cmd, function(run_err, output)
		vim.fn.delete(path)
		if run_err then
			callback(run_err, nil)
			return
		end
		if not output or output:match("^%s*$") then
			callback("HTML renderer produced no output", nil)
			return
		end
		callback(nil, output)
	end)
end

return M
