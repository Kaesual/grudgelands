# `grug_farming` media ledger

The mod ships no new media files. Its node and inventory images are runtime
texture compositions of media already shipped by the named dependency; the
source files are not copied or modified on disk.

| Runtime family | Source textures | Shipped owner and licence | Treatment |
|---|---|---|---|
| Dry and wet crop soil | `default_dirt.png` | minetest_game contributors; CC BY-SA 3.0 (`mods/BASE/default/license.txt`) | Engine `^[colorize` modifiers distinguish dry furrows, wet top and wet sides |
| Crop stages and seeds | Each existing harvest item's `inventory_image` (the exact sources are ledgered by `grug_cooking` or `grug_gathering`) | Existing Grudgelands dependency ledger and vendored `default` licence | Engine `^[colorize` modifiers darken early stages and tint the seed icon; no derived file is distributed |
| Tier-one hoe | `default_tool_steelaxe.png` | minetest_game contributors; CC BY-SA 3.0 (`mods/BASE/default/license.txt`) | Engine `^[colorize` modifier gives the wooden-brown farming-tool treatment |
