# Lane S headless evidence

Captured on 2026-09-17 with seed `15912857179583385436` and Lane S ports
31100–31132. Every server ran through `tools/luanti_headless.sh`, under
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

## Stag unload, save and reload

The review probe supersedes the earlier single-tag lifetime evidence. It
places stationary stags 32 and 160 nodes from the Lua-visible player object,
holds both blocks, releases them at second 10, and forces them again at second
25. `server_unload_unused_data_timeout = 2` bounds the save. Ambient spawn ABMs
are refused by the disposable probe, and every post-reload object whose real
entity name is `grug_mobs:stag` is counted; the result does not depend on a
probe-only field surviving the terminal data.

The old callback-removal snapshot was captured with this command:

```sh
XDG_RUNTIME_DIR=/tmp/r5-xdg-baseline3 \
  tools/spawn_probe/run_despawn.sh round3-baseline3 31125 1 1
```

The runner's obsolete one-object expectation failed, but the engine completed
normally and its independently checked final census was `near=2 far=2`. Thus
the callback's returned tombstone was stored before deactivation and produced
far stags on reload. Two repetitions on ports 31127 and 31129 instead ended
with `far=0`, demonstrating why removal from inside `get_staticdata` was not a
reliable deletion mechanism. The reproducing log is retained as
`round3-baseline-resurrection/lifetime.log`.

The fixed snapshot was run with the observed protected-control count as a hard
expectation:

```sh
XDG_RUNTIME_DIR=/tmp/r5-xdg-fixed3 \
  tools/spawn_probe/run_despawn.sh round3-fixed4 31128 2 0
```

It passed: the protected near stag is present for the full loaded intervals,
while the 160-node marker briefly activates at second 29, is consumed, and the
name census stays `far=0` from second 30 through the final second 55. See
`round3-fixed-terminal/lifetime.log`. The earlier unconditional unload removal
at the lane base made `mob_expire()` irrelevant because `remove_far_mobs =
true`; the distance rule now stores a terminal marker, and `mob_activate`
disables static saving before removing that transient object.

## Active-mob lifecycle counter

The round-4 probe adds an eight-second preparation phase before creating the
two stags. This lets the forced blocks load and unrelated start entities settle
before the probe records its counter baseline. It then releases the blocks at
second 18, forces them again at second 33 and finishes at second 63. Every
lifetime row records both mobs_redo's `active_mobs` value and an independent
512-node census of active `_cmi_is_mob` Lua entities.

Command:

```sh
XDG_RUNTIME_DIR=/tmp/r5-xdg-round4 \
  tools/spawn_probe/run_despawn.sh round4-fixed-counter-final 31132 2 0
```

The run passed. At second 8 the counter and census are both 2; after unload
they are both 0 from seconds 20 through 33. The far marker is visible at
second 36 and absent from second 37 onward. At second 40 the protected static
records have activated and both measurements are 3: the two name-counted near
stags plus one other mob object loaded by the forced area. They stay equal
through the final `near=2 far=0 active=3 mob_objects=3` line at second 63.
An all-row comparison found no counter/census mismatch. See
`round4-fixed-counter-final/lifetime.log`.
