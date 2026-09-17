# Lane S headless evidence

Captured on 2026-09-17 with seed `15912857179583385436` and Lane S ports
31100–31111. Every server ran through `tools/luanti_headless.sh`, under
`nice -n 19`, with an isolated Flatpak runtime directory under `/tmp`.

## Natural spawn rate

The base and changed snapshots were both archived from lane base
`6a19bfde`; only the changed snapshot received the candidate
`minetest.conf`. Both snapshots then received
`tools/spawn_probe/player_shim.patch`. A dedicated server has no real client
ObjectRef, so the probe-only patch lets the unmodified mobs_redo player
presence gate recognize the stationary probe table. The probe also exposes
that table through both `get_connected_players()` and
`get_objects_inside_radius()`. Natural ABMs, node/light/day checks, roster
policy, density caps and distance checks remain production code.

Commands, run concurrently:

```sh
XDG_RUNTIME_DIR=/tmp/r5-flatpak-rate-before6 \
  tools/spawn_probe/run_rate.sh baseline-12 31112
XDG_RUNTIME_DIR=/tmp/r5-flatpak-rate-after6 \
  tools/spawn_probe/run_rate.sh after-24 31115
```

The 120-second-per-boot ceiling cannot hold one 180-second window. Each runner
therefore measures three consecutive 60-second windows on the same fresh world
and canonically sums them. Only names present in `mobs.spawning_mobs` count;
start guards, villagers, traders and elders do not. Base range 12 produced
17 + 14 + 15 = **46**, or **15.333/minute**. Range 24 produced
15 + 22 + 18 = **55**, or **18.333/minute**. The larger refusal radius did not
collapse start-zone supply. See `baseline-12/summary.txt`,
`after-24/summary.txt` and the six server logs.

## Stag unload lifetime

The stationary stag is 32 nodes from the Lua-visible player object. It carries
`remove_ok = true`, matching an existing entity after one save/reactivation.
The probe holds its block, releases it at second 10, and forces and loads it
again at second 25. `server_unload_unused_data_timeout = 2` bounds the probe.

Commands, run concurrently:

```sh
XDG_RUNTIME_DIR=/tmp/r5-flatpak-despawn-base4 \
  tools/spawn_probe/run_despawn.sh baseline-despawn 31118 false
XDG_RUNTIME_DIR=/tmp/r5-flatpak-despawn-fixed4 \
  tools/spawn_probe/run_despawn.sh fixed-despawn-48-128 31119 true
```

The base stag is inactive after the unload and never returns; the final line is
`alive=false`. The fixed stag serializes while inactive, is active again from
second 27 through second 40, and ends `alive=true`. The cause is the old
unconditional unload removal in `mobs/api.lua:3357-3366` at the base commit:
with `remove_far_mobs = true` and `remove_ok = true`, it calls `remove_mob`
without consulting any player distance. `mob_expire()` is not involved because
its guard returns immediately when `remove_far_mobs` is true
(`mobs/api.lua:3537-3540` at the base commit). See both `lifetime.log` files.
