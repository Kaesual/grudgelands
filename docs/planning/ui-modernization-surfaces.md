# UI modernization — surface census

Source audit, 2026-10-24, base
`8f41fb533bf4b00c62149dac16953ba79631bb8c`. This is planning evidence for the
[proposed round](ui-modernization-plan.md), not a claim of runtime coverage.
Paths below are relative to the repository root. A row is a surface family,
not a count of individual screens; states and embedded fragments also matter.
The implementer must confirm each row against its actual starting commit.

Method: searched Lua producers/callers of `show_formspec`,
`set_inventory_formspec`, `set_formspec_prepend`, `register_page`,
`register_tab` and formspec strings throughout `mods/`; followed the shared
frame, node-session and service builders, including forms built as fragments.
Comments, inactive vendor paths and removed features were checked separately.
This static census does not prove every permission or interaction works.

## Inventory and privileged pages

The order comes from [inventory/ui.lua](../../mods/PLAYER/grug_inventory/ui.lua).
Seven ordinary pages plus Admin Mail and five Creative categories can produce
**13 main tabs**. Creative is determined by `core.is_creative_enabled`, not
simply whether a player is an administrator. Admin Mail uses `mail_admin`.

| Surface | Source owner / fragments | Access and states to retain | Lane |
|---|---|---|---|
| Inventory | [pages.lua](../../mods/PLAYER/grug_inventory/pages.lua), [ui.lua](../../mods/PLAYER/grug_inventory/ui.lua) | Normal inventory; bags, sorting, full flow, belt, quiver, currency, A/B; native transfers | INVENTORY |
| Character | [pages.lua](../../mods/PLAYER/grug_inventory/pages.lua), [guild/store.lua](../../mods/PLAYER/grug_guild/store.lua), [achievements/init.lua](../../mods/PLAYER/grug_achievements/init.lua), [housing/interface.lua](../../mods/PLAYER/grug_housing/interface.lua) | Stats/Effects/Achievements subpages, class/race/equipment/model, cloak selection, guild reputation and housing status; actual worn slots and tooltips | INVENTORY |
| Talents & Skills | [talents_ui.lua](../../mods/PLAYER/grug_classes/talents_ui.lua), [talent_graph_ui.lua](../../mods/PLAYER/grug_classes/talent_graph_ui.lua), [skills/page.lua](../../mods/PLAYER/grug_skills/page.lua) | Class trees, node states, respec confirmation, scrolling detached skill catalog; no-class state | INVENTORY |
| Crafting | [jobs/ui.lua](../../mods/PLAYER/grug_jobs/ui.lua), [overview.lua](../../mods/PLAYER/grug_jobs/overview.lua), [craft_box.lua](../../mods/PLAYER/grug_jobs/craft_box.lua), [details.lua](../../mods/PLAYER/grug_jobs/details.lua), [sources.lua](../../mods/PLAYER/grug_jobs/sources.lua), [operation_box.lua](../../mods/PLAYER/grug_jobs/operation_box.lua), [queue_box.lua](../../mods/PLAYER/grug_jobs/queue_box.lua) | Professions, filters, favourites, recipe details/sources, crafts/enchants/upgrades, queue, unavailable/empty states | CRAFT |
| Party & PvP | [parties/ui.lua](../../mods/PLAYER/grug_parties/ui.lua), [pvp/page.lua](../../mods/PLAYER/grug_pvp/page.lua) | Solo/member/leader, invitations, roster and faction/PvP controls | INVENTORY |
| Map & Quests entry and separate window | [map/page.lua](../../mods/PLAYER/grug_map/page.lua), [window.lua](../../mods/PLAYER/grug_map/window.lua), [quest_box.lua](../../mods/PLAYER/grug_map/quest_box.lua) | Responsive map, layers/markers, quest list/details, track/abandon paths, return and lifecycle | QUESTS / MAP |
| Help | [help.lua](../../mods/PLAYER/grug_inventory/help.lua), [ambience/init.lua](../../mods/CORE/grug_ambience/init.lua) | Every subpage, Sound enable/volume controls, About/version and URL actions; long text and keyboard focus | INVENTORY |
| Admin Mail | [mail/admin.lua](../../mods/PLAYER/grug_mail/admin.lua) | `mail_admin`; tickets, replies, announcement/broadcast composition and confirmations; live grant/revoke and stale submissions | PRIVILEGED |
| Creative: All, Nodes, Tools, Items, Food | [creative/inventory.lua](../../mods/BASE/creative/inventory.lua), Food registration in [inventory/ui.lua](../../mods/PLAYER/grug_inventory/ui.lua) | Creative enabled per player/server; search, pagination, no results, detached item source/inbox/trash and transfer rules | PRIVILEGED |

## Containers, stations and world editors

| Surface | Source owner / fragments | Access and states to retain | Lane |
|---|---|---|---|
| Ordinary and locked chests | [default/chests.lua](../../mods/BASE/default/chests.lua), its own `open_chests` sessions (not node_formspec) | Actual node inventories, locking/protection, delayed `after(0.2)` open, concurrent viewers and lid/session cleanup; retained key callback assessed below | CONTAINERS |
| Default furnace | [default/furnace.lua](../../mods/BASE/default/furnace.lua), [inventory/furnace_progress.lua](../../mods/PLAYER/grug_inventory/furnace_progress.lua) | Input/fuel/output, idle/burning/blocked/empty progress, dynamic per-viewer updates | CONTAINERS |
| Profession furnace and dual furnace | [jobs/workspaces.lua](../../mods/PLAYER/grug_jobs/workspaces.lua), [smelting/node.lua](../../mods/ITEMS/grug_smelting/node.lua) | Shared world station with private player workspace/detached views, progress, fuel/results and distance/claim checks | CONTAINERS |
| Bookshelf and vessels shelf | [default/nodes.lua](../../mods/BASE/default/nodes.lua), [vessels/init.lua](../../mods/BASE/vessels/init.lua) | Real container lists, empty-slot art, restrictions/protection; shared station frame | CONTAINERS |
| Claim Stone | [housing/stone_form.lua](../../mods/PLAYER/grug_housing/stone_form.lua), [interface.lua](../../mods/PLAYER/grug_housing/interface.lua) | Owner; draft/activation, fuel, access list, waypoint tab, recovered belongings, pickup confirmation and notices | CONTAINERS |
| Sign editor | [default/nodes.lua](../../mods/BASE/default/nodes.lua), [node_formspec.lua](../../mods/BASE/default/node_formspec.lua) | Protected node editing, existing text, submit/close and session identity | AUXILIARY |
| Book reading/writing | [default/craftitems.lua](../../mods/BASE/default/craftitems.lua) | Writer/reader, title/text, paging and existing save behavior; legacy coordinates | AUXILIARY |

## NPCs, services and other dialogs

| Surface | Source owner / fragments | Access and states to retain | Lane |
|---|---|---|---|
| Quest giver | [quests/npc.lua](../../mods/PLAYER/grug_quests/npc.lua) | Offer, active, ready, completion text, story/side groups, fixed and choice rewards, long text; faction/range/session checks | QUESTS / MAP |
| Traders and camp vendors | [traders/trade.lua](../../mods/ENTITIES/grug_traders/trade.lua), [guild/vendor.lua](../../mods/PLAYER/grug_guild/vendor.lua), [exchange.lua](../../mods/PLAYER/grug_guild/exchange.lua) | Buy/sell, quantities, inactive hotbar, stock/eligibility, guild trade-in and rank-locked page, repair handoff | SERVICES |
| Repair | [repair/providers.lua](../../mods/ITEMS/grug_repair/providers.lua) | Service provider, damaged items/all repaired, individual/all quotes, stale selection and insufficient funds | SERVICES |
| Crown service | [traders/crown.lua](../../mods/ENTITIES/grug_traders/crown.lua) | Eligible items, pages, fee/selection and existing application behavior | SERVICES |
| Profession trainers | [jobs/trainers.lua](../../mods/PLAYER/grug_jobs/trainers.lua) | Learning, current professions, limits/prerequisites, unlearn confirmation, variable greeting length | SERVICES |
| Riding Trainer and Shipwright | [mounts/trainer.lua](../../mods/PLAYER/grug_mounts/trainer.lua) | Shared service form; available, owned, prerequisite/level-locked and unaffordable ranks; faction/range validation | SERVICES |
| Innkeeper | [home/innkeeper.lua](../../mods/PLAYER/grug_home/innkeeper.lua) | Existing home bind action and current-home state | SERVICES |
| Waystones | [home/waypoints.lua](../../mods/PLAYER/grug_home/waypoints.lua) | Discovery/list/travel, known destinations, faction and travel rules | SERVICES |
| Guild lift | [guild/lift.lua](../../mods/PLAYER/grug_guild/lift.lua) | Own faction, depth destinations, eligibility and return/travel handling | SERVICES |
| Housing manager | [housing/manager.lua](../../mods/PLAYER/grug_housing/manager.lua) | Player housing service, Claim Stone eligibility/receipt and refusals; not an administrator-only interface | SERVICES |
| Player mailbox | [mail/window.lua](../../mods/PLAYER/grug_mail/window.lua) | Letters/announcements/compose/To admin, attachment lists, reports/deletion, draft preservation and close returns; node range | AUXILIARY |
| Character creation, appearance and arrival preparation | [classes/selection.lua](../../mods/PLAYER/grug_classes/selection.lua), [visuals/creation.lua](../../mods/PLAYER/grug_visuals/creation.lua) | New character choices and explicit Create; separate Preparing/progress/ready/failure/retry window, including reconnect during arrival; both use the opaque no-prepend background and inventory suspension | AUXILIARY |
| Welcome | [inventory/welcome.lua](../../mods/PLAYER/grug_inventory/welcome.lua) | Join/arrival guide, link actions, dismiss; long text | AUXILIARY |
| Quickbar | [quickbar/init.lua](../../mods/PLAYER/grug_quickbar/init.lua) | Mount/boat options, belt, A/B and home return, mounted/unmounted states | AUXILIARY |
| Coin withdrawal | [money/coins.lua](../../mods/PLAYER/grug_money/coins.lua) | Amount/denominations, validation and return to inventory | AUXILIARY |
| Mob spawner settings | [mobs/spawner.lua](../../mods/ENTITIES/mobs/spawner.lua) | Registered node loaded by mobs/init.lua; node right-click opens, edits check protection; range/node session checks. Do not label it admin-only based on appearance | AUXILIARY |
| Mob Reset Stick texture editor | [mobs/crafts.lua](../../mods/ENTITIES/mobs/crafts.lua) | Registered tool hidden from Creative listing, obtainable by administrative item grant; sneak-use texture form. Tool possession is not itself a privilege check | AUXILIARY |

The ordinary mailbox's **To admin** page is player-facing; it is distinct
from the privileged **Admin Mail** inventory page. The Housing Manager is
also a player service. Privileged testing must use the real access predicate,
not a name-based classification of windows.

## Shared foundations and exceptions

- [default/init.lua](../../mods/BASE/default/init.lua) supplies the old
  prepend: world dimming, list colors and an opaque-centered nine-slice image.
  [sounds/init.lua](../../mods/CORE/grug_sounds/init.lua) appends click styles.
  Creation explicitly opts out of the prepend and restores its click style.
- [inventory/ui.lua](../../mods/PLAYER/grug_inventory/ui.lua) owns the shared
  inventory frame, ordering, selection/area helpers and full/short/station
  views. Container consumers need deliberate conversion alongside the tabs.
- [sfinv/api.lua](../../mods/BASE/sfinv/api.lua) owns page lifecycle and native
  tab dispatch. Custom navigation must keep one authoritative dispatch path.
- [core/mod.conf](../../mods/CORE/grug_core/mod.conf),
  [sounds/mod.conf](../../mods/CORE/grug_sounds/mod.conf),
  [classes/mod.conf](../../mods/PLAYER/grug_classes/mod.conf) and
  [inventory/mod.conf](../../mods/PLAYER/grug_inventory/mod.conf) explain why
  putting every shared primitive only in grug_inventory creates load-order
  difficulties. Runtime seams must not become reverse mod dependencies.
- Creative writes local `listcolors[]`; many pages write local button colors.
  Theme defaults alone do not remove all old styling. Native slot colors apply
  to the form, so combining differently styled inventories needs care.
- [node_formspec.lua](../../mods/BASE/default/node_formspec.lua), housing's
  stone form and map's window already manage `core.show_formspec` lifetimes.
  A style wrapper must not bypass their replacement/cleanup semantics.

## Deliberate non-surfaces and limits

- The original `sfinv.make_formspec` and `theme_inv` in
  [sfinv/api.lua](../../mods/BASE/sfinv/api.lua) are replaced by
  [inventory/ui.lua](../../mods/PLAYER/grug_inventory/ui.lua). The vanilla
  Crafting body in [sfinv/init.lua](../../mods/BASE/sfinv/init.lua) is replaced
  by `sfinv.override_page` in [jobs/ui.lua](../../mods/PLAYER/grug_jobs/ui.lua).
  Restyling these superseded bodies would not change the shipped UI.
- `default.gui_survival_form` and its `default.get_hotbar_bg` builder in
  [default/init.lua](../../mods/BASE/default/init.lua) have no external
  consumer in shipped `mods/`; do not mistake them for the active inventory.
  The active inventory still draws `gui_hb_bg.png` from its own ui.lua.
- The locked chest's retained `on_key_use` callback builds
  `default:chest_locked` without a view context. The shipped game has no key
  mod or caller of `on_key_use` (producer/caller search in `mods/`; the engine
  builtin also supplies none). Record this distinct path without reviving it.
  If a later main change makes it reachable, include its form/session variant
  explicitly before integration. Normal locked-chest right-click is live and
  is covered above; it uses `default:chest` and the chest's own session table.

- [beds/init.lua](../../mods/BASE/beds/init.lua) makes beds inert decoration.
  [grug_decor/init.lua](../../mods/ITEMS/grug_decor/init.lua) and its import
  modules omit vendor furniture inventories/forms. No bed/decor UI is missing.
- Forge/bench/brewing station proximity is not a reason to add dialogs;
  [jobs/workspaces.lua](../../mods/PLAYER/grug_jobs/workspaces.lua) identifies
  the actual furnace workspace forms, while Crafting owns the other operations.
- The old naming dialog remains in [mobs/api.lua](../../mods/ENTITIES/mobs/api.lua),
  but its trigger needs `mobs:nametag`, removed from registered content
  ([content_curation.lua](../../mods/ITEMS/grug_materials/content_curation.lua)).
  Treat it as a dormant vendor path, not a feature to restore. Recheck this
  reachability conclusion at integration.
- Command-only debug facilities have no form to restyle. HUDs and engine-owned
  menus require a separate scope decision; the proposed boundary is in the plan.
- The plan requires a fresh delta scan after the quest rounds: sources may
  have gained states or new dialogs since this snapshot. Static absence is
  not proof of visual acceptance on either client.
