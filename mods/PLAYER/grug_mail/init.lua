-- Mail (Round 48, docs/design/mail.md; spec docs/planning/mail-plan.md):
-- mailboxes beside the waystones of the capitals and starting villages,
-- letters between players of one faction with postage and up to four
-- attached stacks, admin and system letters, messages to the admin
-- (tickets), announcements to all players and the unread count beside the
-- minimap. Mail lives in this mod's storage (store.lua), never on the map.
grug_mail = {}

local path = core.get_modpath(core.get_current_modname())
grug_mail.model = dofile(path .. "/model.lua")
grug_mail.store = dofile(path .. "/store.lua")
dofile(path .. "/api.lua")
dofile(path .. "/window.lua")
dofile(path .. "/admin.lua")
-- The starter quest and the game's own letters (lane QUEST).
grug_mail.texts = dofile(path .. "/texts.lua")
dofile(path .. "/letters.lua")
dofile(path .. "/quest.lua")
