-- grug_text/layout.lua: the pure part of the text module (no engine call),
-- so the portable fixture (tools/r68_text) runs it as the game does.
--   codepoints(text)            UTF-8 -> list of code points
--   wrap(text, lines, chars)    the Round 68 wrapping rule (ruling 4)
--   canvas(lines, chars)        the texture's pixel size for a surface
--   texture(rows, surface, map) the `[combine` string of wrapped rows
--   load_charmap(path)          characters.tsv -> {[code point] = texture}
-- Returned as a table; init.lua and the fixture dofile it.

local M = {}

-- One glyph cell: 6 px wide (a 5 or 6 px glyph and its gap) and 12 px tall
-- (accents in rows 0-2, capitals in 3-8, descenders to 10), so a line is
-- 12 px and a monospaced line of N characters is 6 N px.
M.CELL_W, M.CELL_H = 6, 12
-- One glyph pixel is 1/128 node, an eighth of a 16 px node texture's pixel:
-- every surface uses this one scale, so all text looks alike.
M.PIXEL = 1 / 128
M.PLACEHOLDER = "grug_text_rc"

local SPACE, NEWLINE, TAB, NBSP = 32, 10, 9, 0xA0
local byte, char, concat, floor = string.byte, string.char, table.concat, math.floor

-- UTF-8 to code points. A malformed or truncated sequence becomes one
-- U+FFFD per bad byte (shown as the placeholder glyph), never an error.
function M.codepoints(text)
	local out, i, n = {}, 1, #text
	while i <= n do
		local b = byte(text, i)
		local len, code
		if b < 0x80 then
			len, code = 1, b
		elseif b >= 0xC2 and b <= 0xDF then
			len, code = 2, b - 0xC0
		elseif b >= 0xE0 and b <= 0xEF then
			len, code = 3, b - 0xE0
		elseif b >= 0xF0 and b <= 0xF4 then
			len, code = 4, b - 0xF0
		end
		if len and len > 1 then
			for k = i + 1, i + len - 1 do
				local c = byte(text, k)
				if not c or c < 0x80 or c > 0xBF then
					len = nil
					break
				end
				code = code * 64 + (c - 0x80)
			end
		end
		if len then
			out[#out + 1] = code
			i = i + len
		else
			out[#out + 1] = 0xFFFD
			i = i + 1
		end
	end
	return out
end

-- Wraps `text` into at most `lines` rows of at most `chars` code points
-- (ruling 4): a newline starts a new row; rows break at spaces (a run of
-- spaces or tabs is one break, and a row neither starts nor ends with one);
-- a word longer than a row starts on its own row and is broken inside;
-- whatever does not fit into `lines` rows is cut off. Other control
-- characters are dropped. Returns a list of rows, each a list of code
-- points (an empty row from a blank line is kept, trailing empty rows are
-- not).
function M.wrap(text, lines, chars)
	local rows = {}
	local row = {}
	local function emit()
		if #rows < lines then rows[#rows + 1] = row end
		row = {}
	end
	local function add_word(word)
		if #word == 0 then return end
		if #row > 0 and #row + 1 + #word <= chars then
			row[#row + 1] = SPACE
			for _, c in ipairs(word) do row[#row + 1] = c end
			return
		end
		if #row > 0 then emit() end
		local i = 1
		while #word - i + 1 > chars do
			for k = i, i + chars - 1 do row[#row + 1] = word[k] end
			emit()
			i = i + chars
		end
		for k = i, #word do row[#row + 1] = word[k] end
	end
	local word = {}
	for _, c in ipairs(M.codepoints(text or "")) do
		if #rows >= lines then break end
		if c == NEWLINE then
			add_word(word)
			word = {}
			emit()
		elseif c == SPACE or c == TAB then
			add_word(word)
			word = {}
		elseif c >= 32 and c ~= 127 and not (c >= 0x80 and c < 0xA0) then
			word[#word + 1] = c
		end
	end
	add_word(word)
	if #row > 0 then emit() end
	while #rows > 0 and #rows[#rows] == 0 do rows[#rows] = nil end
	return rows
end

local function pow2(n)
	local p = 1
	while p < n do p = p * 2 end
	return p
end

-- The texture of a surface of `lines` x `chars`: the text block's size and
-- the canvas, rounded up to powers of two (a driver without NPOT support,
-- the web build's possibly, would otherwise resample the glyphs). The
-- block sits centred on the canvas, so the entity's centre is the block's.
function M.canvas(lines, chars)
	local block_w, block_h = chars * M.CELL_W, lines * M.CELL_H
	return pow2(block_w), pow2(block_h), block_w, block_h
end

-- The `[combine` string for `rows` (from wrap) on `surface` = {lines,
-- chars, ink, align = "center"|"left", valign = "center"|"top"}, glyph
-- names from `charmap`. nil when no row has a visible glyph.
function M.texture(rows, surface, charmap)
	local w, h, block_w, block_h = M.canvas(surface.lines, surface.chars)
	local left = floor((w - block_w) / 2)
	local top = floor((h - block_h) / 2)
	if surface.valign ~= "top" then
		top = top + floor((surface.lines - #rows) * M.CELL_H / 2)
	end
	local parts, glyphs = {"[combine:", w, "x", h}, 0
	for r, row in ipairs(rows) do
		local x = left
		if surface.align ~= "left" then
			x = x + floor((block_w - #row * M.CELL_W + 1) / 2)
		end
		local y = top + (r - 1) * M.CELL_H
		for _, code in ipairs(row) do
			if code ~= SPACE and code ~= NBSP then
				local name = charmap[code] or M.PLACEHOLDER
				parts[#parts + 1] = ":" .. x .. "," .. y .. "=" .. name .. ".png"
				glyphs = glyphs + 1
			end
			x = x + M.CELL_W
		end
	end
	if glyphs == 0 then return nil end
	parts[#parts + 1] = "^[multiply:" .. surface.ink
	return concat(parts)
end

-- characters.tsv (tools/r68_text/import_font.py): `<character>\t<texture>`
-- per line, the character one UTF-8 code point.
function M.load_charmap(path)
	local map = {}
	local file = assert(io.open(path, "rb"))
	for line in file:lines() do
		local glyph, name = line:match("^(.-)\t([%w_]+)\r?$")
		if glyph then
			local codes = M.codepoints(glyph)
			if #codes == 1 then map[codes[1]] = name end
		end
	end
	file:close()
	return map
end

-- Back to UTF-8 (the fixture prints rows with it).
function M.utf8(row)
	local out = {}
	for _, c in ipairs(row) do
		if c < 0x80 then
			out[#out + 1] = char(c)
		elseif c < 0x800 then
			out[#out + 1] = char(0xC0 + floor(c / 64), 0x80 + c % 64)
		elseif c < 0x10000 then
			out[#out + 1] = char(0xE0 + floor(c / 4096), 0x80 + floor(c / 64) % 64, 0x80 + c % 64)
		else
			out[#out + 1] = char(0xF0 + floor(c / 262144), 0x80 + floor(c / 4096) % 64,
				0x80 + floor(c / 64) % 64, 0x80 + c % 64)
		end
	end
	return concat(out)
end

return M
