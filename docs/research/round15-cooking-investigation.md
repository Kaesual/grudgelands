# Round 15 Cooking trainer investigation

Date: 2026-09-21. Investigator: native Astra. Scope: read-only diagnosis of two
players reporting that learning Cooking on one character makes the other see
“You already know Cooking” / “Unlearn” at the same trainer. No production or
player-world data was changed; no Lua, native, client-bot or GUI test was run.

**Result: no confirmed production cause yet. The available local log contains
no instrumented trainer interaction, so it cannot distinguish wrong displayed
state from an actual second-player metadata change.** The repeated user report
remains open; a passing mock is not evidence that the report did not happen.

## What was checked beyond the earlier mock

The Round 14 fixture directly calls `open_trainer` and installs its own
per-name metadata tables. It establishes isolation only after the caller and
metadata store have already been assumed correct. Repeating it would not test
an engine identity, NPC invocation or client formspec routing problem.

The new investigation followed the actual surrounding paths:

1. **No shared learned-default table exists.** In
   `mods/PLAYER/grug_jobs/state.lua:44–55`, `has(player,"cooking")` reads only
   `player:get_meta():get_int("grug_jobs:learned:cooking") == 1`. The shared
   `PROFESSIONS` table contains display name and primary/secondary category,
   not ownership. `learn` obtains the provided player's metadata anew and
   writes learned/level/crafts there (`:57–82`). `unlearn` follows the same
   rule. There is no cached PlayerMetaRef or global “Cooking learned” flag.
2. **NPCs store their profession, not the last learner.** The real trainer
   installation in `start_npcs.lua:1049–1053` stores a profession string and
   title. `start_villagers.lua:1024–1034` passes its current `clicker`, current
   profession, position and entity to `jobs.open_trainer`. The closure captures
   no previous player; the riding branch exits separately. Vendored mobs_redo
   registers `def.on_rightclick` directly (`api.lua:4128`).
3. **Forms and sessions are per authenticated player.** In
   `trainers.lua:16–50`, both the status and Learn/Unlearn button derive from
   the supplied player's current `has` value. `open_trainer` stores the session
   under `get_player_name()` and sends to that same name (`:53–62`). Submitted
   fields retrieve the sender's session and pass the sender to learn/unlearn
   (`:73–108`). A shared form name is normal and does not identify its owner.
4. **The engine routes both ends by the connection's identity.**
   `serverpackethandler.cpp:884–914,1213` resolves the interacting player from
   peer ID before calling the entity's right-click callback. Inventory fields
   resolve `RemotePlayer` and `PlayerSAO` from peer ID (`:1376–1412`); allowed
   form names are held per peer, not globally. `Server::showFormspec`
   (`server.cpp:3522–3537`) resolves the supplied player name and sends only
   to that player's peer. `l_server.cpp:402–409` forwards the name unchanged.
5. **PlayerMeta identity is not inferred from userdata equality.**
   `l_object.cpp:1725–1733` creates the metadata reference from the object's
   PlayerSAO's player name. `l_playermeta.cpp:17–21` resolves that name back to
   the current player's own `m_meta` (`server/player_sao.h:180,222`). SQLite
   metadata load/save is keyed by the same player name
   (`database-sqlite3.cpp:462–466,551–560,610–618`). No shared fallback metadata
   store was found in that path.
6. **Creation and reconnect do not grant Cooking.** Repository searches for
   `grug_jobs.learn`, its learned/primary keys and `open_trainer` found the sole
   production learning call in the trainer receive-fields callback. Character
   creation, class/race selection and starter equipment grant no profession.
   Jobs has no join handler that copies another player's state. Same-character
   reconnect deliberately retains learned metadata; this is ordinary current-
   world persistence, not a proposed old-world workaround.
7. **UI and real authorization use the same value.** The Cooking book button
   (`grug_jobs/ui.lua:573–575,590–592`), profession level and protected recipe
   authorization all call the same `has`. Universal Basics/automatic cooking
   does not set the learned key. Therefore an incorrect trainer-only display
   can be distinguished from actual entitlement by checking the book and a
   Cooking-gated recipe, without consuming or resetting player data.

## Targeted local evidence

Read only matching trainer/Cooking/startup lines from the existing Flatpak
`debug.txt`, not unrelated chat or inventory content. At inspection:

- File mtime: 2026-09-21 22:51:48 +0200; size 36,169,577 bytes.
- There are **zero** `[grug_jobs] trainer_` entries in that log.
- The only `Learned Cooking.` chat entry is 2026-09-21 **10:40:02**, before
  the current diagnostic trainer file's 20:55:50 mtime.
- The latest recorded local server start is **21:44:40**. This does not prove
  where the reported two-client interaction took place, only that this local
  log supplies no instrumented open/learn sequence from it.
- The installed Flatpak game and repository state/trainer files are byte-
  identical. SHA-256: `state.lua`
  `00137b64960b75f21b4bb16ace742d1585a3908ed9983bd7119f7ee4a4e9a58e`;
  `trainers.lua`
  `f6c767a2ad7b6f3ba77d5baf38fc185585259aa25c028eea56b9a39da1052e72`.

Consequently an out-of-sync installed file is not demonstrated. A remote
server, earlier running code or an interaction not represented in this local
log remains an evidence-location question, not a diagnosed explanation.

## Smallest useful next probe

Use two actual clients with different authenticated character names on the
same server running the instrumented trainer file. No bots, seed population,
reinstall, data reset or new profession mechanic is needed. The existing
per-action diagnostics are sufficient for the first split:

1. Before either learns, A and B each open the same Cooking trainer once and
   close without pressing Learn. Both log lines should say
   `known_before=false known_after=false` under their respective names.
2. A opens again, presses Learn exactly once and closes. A's learn line should
   be `false → true`.
3. B opens the same trainer, does not press any action and records the displayed
   status/button. Its open line should remain `false → false`. A's subsequent
   open should remain `true → true`.
4. If B sees the wrong state, capture only that screen, the two character names,
   the server identity/time and the corresponding six or fewer trainer lines.
   Check whether B's Cooking book is actually available. Do not unlearn as a
   diagnostic workaround: that destroys the state being investigated.
5. If sequential use works, repeat once with both trainer windows already open
   before A learns, then have B close and reopen. This specifically exercises
   the shared-NPC/shared-form-name timing boundary missing from the old fixture.
6. One reconnect of B checks that the display agrees with persisted entitlement;
   it is not a substitute for the before/after records.

Interpretation of the captured evidence:

| Observation | Boundary implicated |
| --- | --- |
| No trainer log for the displayed interaction | Wrong/missing server log, running build, or interaction route; establish that boundary first |
| B's open logs `false`, but B sees Unlearn | Rendered/received formspec versus authoritative metadata; inspect the exact outgoing B form and client display next |
| B changes to `true` with an unexpected B learn event | Actual field delivery/action sequence; inspect the submitted field and sender, not a shared learned table |
| B changes from `false` to `true` with no B learn event | Actual metadata mutation/identity boundary; add bounded before/after named-key snapshots around the real calls on that server |
| B's first baseline is already `true` | The claimed initial state was not captured; investigate when that character obtained entitlement without erasing it |

If the first split still cannot isolate it, a temporary opt-in server probe
should record only the two names, the four jobs keys, NPC socket/profession,
actor at the real right-click boundary and outgoing formspec target/state.
It must be read-only, avoid full metadata/inventory dumps and be removed after
one reproduction. Such a native probe requires the two real authenticated
players; fake Lua tables cannot validate C++ PlayerMetaRef or peer routing.

No speculative production fix is recommended before this evidence. The
specific missing input is an instrumented two-client interaction from the
server where the symptom occurs, not another repetition of the prior mock.
