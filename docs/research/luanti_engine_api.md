# Luanti-Engine / Lua-API Briefing

Quelle: `reference_projects/luanti`. Hauptreferenz: `doc/lua_api.md` (~12.700 Zeilen).
Builtin-Lua der Engine: `builtin/`. Beispiel-Game: `games/devtest/`.

## Game- & Mod-Struktur
- Game: `games/<gameid>/` mit `game.conf` (title Pflicht; description, first_mod/last_mod,
  allowed_mapgens/disallowed_mapgens/default_mapgen, disabled_settings — nur
  enable_damage/creative_mode/enable_server, `!`-Präfix erzwingt true; map_persistent,
  author, textdomain, aliases), `minetest.conf` (Default-Settings), `menu/`, `mods/`,
  `settingtypes.txt`. World-embedded Game: `<worldname>/game/` überschreibt alles.
- Mod-Ladepfade: `games/<gameid>/mods/`, `mods/`, `worlds/<name>/worldmods/`.
- `mod.conf`: name, title, description, depends (kommasepariert), optional_depends, textdomain.
- Medien: `textures/ sounds/ media/ models/ locale/ fonts/`, auto-transfer an Clients.
  Namen `a-zA-Z0-9_.-`; Bilder .png/.jpg/.tga, Sounds .ogg, Modelle .x/.b3d/.obj/.gltf/.glb
  (glb empfohlen, 1 Animation), Fonts .ttf/.woff. Dateien >~16MB abgelehnt.
- Modpacks: Ordner mit `modpack.conf`.
- Namen: `modname:whatever`; Präfix `:` überschreibt fremde Registrierung (braucht Dependency).
- **`core.*` ist kanonisch, `minetest.*` deprecated Alias.** Mods laufen NUR serverseitig.

## Lua-Umgebung & Sandbox
- Lua 5.1 / LuaJIT. Zahlen = C-Doubles, sicherer Int-Bereich ±(2^53−1).
- Sandbox-Whitelist (src/script/cpp_api/s_security.cpp:124-203, bei secure.enable_security):
  - Voll: coroutine, string, table, math, **bit** (LuaJIT BitOp, immer da).
  - Ersetzt/gesichert: dofile, load, loadfile, loadstring, require (pfadbeschränkt).
  - io reduziert (close/flush/read/type/write + secured open); os reduziert
    (clock/date/difftime/getenv/time — KEIN execute/exit); debug/package reduziert.
- `core.request_insecure_environment()` nur für secure.trusted_mods; HTTP via
  `core.request_http_api()` nur secure.http_mods/trusted_mods.
- Global injizierte Extras: dump/dump2; math.hypot/sign/factorial/round/isfinite;
  string.split, string:trim(), string.pack/unpack/packsize (5.4-Backport);
  table.copy/copy_with_metatables/indexof/keyof/insert_all/key_value_swap/shuffle.
- Vektoren: `vector.new(x,y,z)` metatable-basiert, Operatoren überladen;
  add/subtract/length/normalize/direction/distance/rotate/cross/dot/floor/round/offset/
  in_area/random_direction; `vector2.*` für 2D. Plain {x=,y=,z=} überall akzeptiert.
- Serialisierung: core.serialize/deserialize(str[,safe]), core.parse_json/write_json,
  core.pos_to_string/string_to_pos.
- builtin/common/misc_helpers.lua definiert die Helfer; builtin/game/ = Server-Game-API
  (register.lua, item.lua, privileges.lua, hud.lua, knockback.lua, static_spawn.lua ...);
  strict.lua warnt bei undeklarierten Globals.

## Spieler & Stats
- HP: get_hp()/set_hp(hp, reason) (u16, Max via hp_max Object-Property). Breath analog.
- **Persistente Custom-Stats: `player:get_meta()` → PlayerMetaRef** (MetaDataRef:
  get/set_string/int/float, contains, get_keys, to_table/from_table; set_string("",nil)
  löscht). set_attribute/get_attribute sind deprecated.
- set_physics_override({speed, speed_walk, jump, gravity, sneak, ...}) — Multiplikatoren pro Spieler.
- get_player_control() (up/down/left/right/jump/aux1/sneak/dig/place/zoom + movement_x/y).
- set_inventory_formspec (in on_joinplayer), set_formspec_prepend.
- Weitere Persistenz: core.get_mod_storage() → StorageRef (beim Laden holen);
  core.get_meta(pos) → NodeMetaRef (kv + Inventory; Spezialkeys formspec/infotext);
  stack:get_meta() → ItemStackMetaRef (description, color, ...).

## HUD
- hud_add(def)→id, hud_remove, hud_change(id, stat, value), hud_get_all.
- hud_set_flags{hotbar, healthbar, crosshair, wielditem, breathbar, minimap,
  minimap_radar, basic_debug, chat}.
- Element-Typen: image, text (colorize/translate, bold/italic/mono), **statbar**
  (Half-Image-Bars — Custom-HP/Mana), inventory, hotbar, **waypoint** (world_pos +
  Distanzanzeige), image_waypoint, compass, **minimap**.
- set_minimap_modes({{type="surface"|"radar"|"texture"|"off", label, size, texture,
  scale}}, selected); core.hud_replace_builtin("health"|"breath"|"minimap"|"hotbar", def).
- Atmosphäre pro Zone: set_sky/set_sun/set_moon/set_stars/set_clouds.

## Formspecs
- core.show_formspec(playername, formname, fs); Antworten via
  core.register_on_player_receive_fields(player, formname, fields).
- formspec_version[n] + real_coordinates[true] setzen. Elemente: field, textarea,
  button/image_button/button_exit/button_url, list (Inventory), dropdown, checkbox,
  scrollbar, table/textlist, tabheader, hypertext, **model[]** (3D-Vorschau),
  scroll_container, style[]/style_type[], tooltip, box, bgcolor.
- core.formspec_escape für Nutzertext. Node-UI via Node-Meta-Key `formspec`.

## Registrierung & Kampf
- core.register_node/craftitem/tool/entity, core.override_item, core.register_alias,
  core.register_craft. Definitionstabellen: lua_api.md „Definition tables".
- Groups: Dig-Gruppen crumbly/cracky/snappy/choppy/fleshy/explody/
  oddly_breakable_by_hand + level; Node-Gruppen attached_node, falling_node,
  disable_jump, slippery, bouncy, fall_damage_add_percent, not_in_creative_inventory.
- Entities: core.register_entity(name, {initial_properties, on_activate,
  on_step(dtime), on_punch, on_death, on_rightclick, get_staticdata});
  core.add_entity(pos, name, staticdata). Attachments: set_attach(parent, bone, ...);
  Bones: set_bone_override (Radiant! set_bone_position deprecated/Grad).
- **Schaden** = Σ über Gruppen: damage_groups[g] × limit(interval/full_punch_interval,0,1)
  × armor_groups[g]/100. Tool-Caps: full_punch_interval, max_drop_level, groupcaps
  (times/uses/maxlevel), damage_groups. set_armor_groups{fleshy=100,...};
  immortal=1 = kein Schaden + versteckt HP/Breath-HUD.
- Hooks: register_on_punchplayer, register_on_player_hpchange(fn, modifier),
  register_on_dieplayer, register_on_respawnplayer, core.get_hit_params.

## Mapgen
- Mapgens: v5/v6/**v7**/flat/valleys/fractal/carpathian/**singlenode** (eigenes
  Lua-Terrain). Auswahl via game.conf oder core.set_mapgen_setting("mgname","v7",true).
- core.get/set_mapgen_setting (seed als String!), get/set_mapgen_setting_noiseparams,
  get_mapgen_object, get_mapgen_edges, get_spawn_level.
- core.register_biome(def), core.register_ore(def) (scatter/sheet/puff/blob/vein/stratum),
  core.register_decoration(def) (simple/schematic), core.register_schematic.
- Normal-Env-Callback: core.register_on_generated(function(minp, maxp, blockseed)) —
  voller Map-Zugriff.
- **Mapgen-(Emerge-)Env**: core.register_mapgen_script(path) — eigene Lua-Threads,
  KEIN Metadata/globalstep; register_on_generated bekommt dort (vmanip, minp, maxp,
  blockseed); core.save_gen_notify(id, data) → Normal-Env. Verfügbar: Noise,
  get_biome_id/get_heat/get_humidity, set_node/find_node_near, spawn_tree, IPC,
  AreaStore/VoxelManip/VoxelArea/PcgRandom.
- Async-Env: core.handle_async(func, cb, ...), core.register_async_dofile —
  kein Map-/Player-Zugriff.
- VoxelManip: core.get_voxel_manip(), core.get_content_id/get_name_from_content_id,
  VoxelArea, core.generate_ores/generate_decorations(vm).

## Privilegien, PvP, Protection
- core.register_privilege(name, def), core.check_player_privs, core.set_player_privs,
  register_on_priv_grant/revoke, core.register_chatcommand(name, {params, privs, func}).
- Builtin-Privs: interact, shout, fast, fly, noclip, teleport, give, server, ...
  Settings: default_privs.
- Protection: core.is_protected(pos, name) überschreiben (Engine erzwingt nichts),
  core.register_on_protection_violation.
- PvP/Damage-Settings: enable_damage (def false!), enable_pvp (def true),
  creative_mode; lesen via core.settings:get_bool("enable_pvp"). enable_pvp gatet
  Spieler-vs-Spieler-Schaden engine-seitig; eigenes Gating via register_on_punchplayer.

## Spielermodell
- Kein Engine-Skin-API: player:set_properties({visual="mesh", mesh="character.b3d",
  textures={...}, visual_size=...}); Animationen: set_local_animation(idle, walk, dig,
  walk_while_dig, speed) + set_animation. player_api ist Game-Konvention (minetest_game).

## SSCSM / Client-Mods
- SSCSM = in Arbeit, builtin/sscsm_server/init.lua ist leerer Stub → **nicht nutzbar,
  alles serverseitig bauen**. Lokale clientmods/ sind Nutzer-installiert, für Games
  irrelevant (csm_restriction_flags).

## Nützliche Globals/Lifecycle
- core.after(t, fn), core.get_us_time, core.get_worldpath, core.get_modpath,
  core.chat_send_all/player, core.log(level, msg), core.settings,
  core.get_connected_players, core.is_player, core.player_exists,
  core.hash_node_position, core.get_item_group.
- register_on_mods_loaded, register_on_newplayer, register_on_joinplayer(player,
  last_login), register_on_leaveplayer, register_globalstep(dtime),
  register_on_shutdown.
- core.dynamic_add_media (Laufzeit-Medien, z. B. gerenderte Karten-PNGs).
