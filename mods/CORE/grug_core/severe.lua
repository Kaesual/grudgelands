-- The severe-error helper (Round 41 ruling 8): one path for an error the
-- server survives but an administrator must see. It writes one server-log line
-- at error level with the literal prefix [GRUG-SEVERE] (the hosting
-- platform's admin log view highlights it) and shows every player a red chat
-- message, once per key (a failing map chunk reports once, not per retry).
--
-- Both Lua environments load this file: the main one through grug_core
-- (`grug_core.severe`) and the mapgen one by dofile (`grug_mapgen`'s
-- `wp40/r7_mapgen.lua`). The mapgen environment has no chat and no grug_core
-- global, so there `report` logs and hands the chat part to the main thread
-- through gen_notify (`core.save_gen_notify`); `install_main` relays it from
-- the main environment's on_generated. Returns the module table; it publishes
-- no global itself.
local severe = {}

severe.PREFIX = "[GRUG-SEVERE]"
severe.NOTIFY_ID = "grug_core:severe"
severe.CHAT_COLOR = "#ff4040"

-- The log line: prefix, source, summary and the details (one line; a newline
-- in the details is folded so a log view shows the whole record).
function severe.line(source, summary, details)
	local text = severe.PREFIX .. " " .. tostring(source) .. ": " .. tostring(summary)
	if details ~= nil and details ~= "" then
		text = text .. " | " .. tostring(details)
	end
	return (text:gsub("[\r\n]+", " | "))
end

-- The chat text players see (no details: those are for the log).
function severe.chat_text(source, summary)
	return "Severe server error (" .. tostring(source) .. "): " .. tostring(summary) ..
		" The server keeps running; please tell an administrator."
end

local shown = {}

-- Shows the red chat message once per key (main environment only).
local function show(key, source, summary)
	if key ~= nil then
		if shown[key] then return false end
		shown[key] = true
	end
	core.chat_send_all(core.colorize(severe.CHAT_COLOR,
		severe.chat_text(source, summary)))
	return true
end

-- Reports one severe error: the log line now, the chat message once per key.
-- In the mapgen environment the chat part travels with the chunk being
-- generated (call it inside on_generated). Returns the log line.
function severe.report(source, summary, details, key)
	local text = severe.line(source, summary, details)
	core.log("error", text)
	if type(core.chat_send_all) == "function" then
		show(key, source, summary)
	elseif type(core.save_gen_notify) == "function" then
		core.save_gen_notify(severe.NOTIFY_ID,
			{source = tostring(source), summary = tostring(summary), key = key})
	end
	return text
end

-- Main environment, at load time: request the gen_notify entry and relay a
-- mapgen report to chat after its chunk is generated.
function severe.install_main()
	core.set_gen_notify({custom = true}, nil, {severe.NOTIFY_ID})
	core.register_on_generated(function()
		local notify = core.get_mapgen_object("gennotify")
		local entry = notify and notify.custom and notify.custom[severe.NOTIFY_ID]
		if type(entry) == "table" then
			show(entry.key, entry.source, entry.summary)
		end
	end)
end

return severe
