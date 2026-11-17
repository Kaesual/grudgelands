-- Text rules for untrusted input (Round 81 lane SAFE; audit 2026-11 X6-01,
-- X6-V1, P5-01): the cut of a raw form field and the UTF-8 byte-length rule.
-- Pure: no engine calls, so a fixture loads this file by dofile. Returns the
-- module table; grug_core publishes it as grug_core.text (init.lua).
local T = {}

-- A raw form field cut to its first `bytes` bytes, as a string ("" for nil).
-- Every raw field is cut with this before a trim or an engine event parser
-- (core.explode_textlist_event and its kin trim their parts) runs on it: the
-- engine accepts up to 640 KiB of field data in one submit
-- (src/network/serverpackethandler.cpp, pkt_read_formspec_fields), and the
-- trim's pattern `^%s*(.-)%s*$` takes time that grows with the square of a
-- run of blanks inside the value.
function T.cut(value, bytes)
	return tostring(value or ""):sub(1, bytes)
end

-- A raw form field cut to `bytes` bytes, then trimmed like string.trim.
function T.cut_trim(value, bytes)
	return T.cut(value, bytes):match("^%s*(.-)%s*$")
end

-- A text box value without control characters, trimmed, at most `limit`
-- bytes. The raw value is cut to 4 x `limit` bytes first (above).
function T.clean_field(value, limit)
	local text = T.cut(value, 4 * limit):gsub("[%c]", "")
	return (text:match("^%s*(.-)%s*$") or ""):sub(1, limit)
end

-- The UTF-8 byte-length rule: the bytes a character with this lead byte has.
function T.utf8_size(lead)
	if lead < 128 then return 1 elseif lead < 224 then return 2 elseif lead < 240 then return 3 end
	return 4
end

-- Whether `char`, one match of a lead byte and the continuation bytes after
-- it (the cleaners' pattern "[%z\1-\127\194-\244][\128-\191]*"), is a whole
-- character: exactly as many bytes as its lead byte announces. A lone lead
-- byte and a run of stray continuation bytes are not; a cleaner drops them,
-- so a malformed run never counts as one character. Every match of valid
-- UTF-8 is whole.
function T.utf8_whole(char)
	return #char == T.utf8_size(char:byte())
end

return T
