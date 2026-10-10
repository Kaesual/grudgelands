# 0.45.1 probe: the riding camera (`/mountcam`)

A throwaway mod (`grug_r451_mc_probe`) for tuning where the camera sits while
riding (0.45.1 fix plan row 8). It is **never shipped**: nothing in `mods/`
depends on it, and the game runs exactly as before without it. It changes
the camera values of the mount model you ride **at runtime, for this server
run only**; nothing is saved and no world data changes. Send the `/mountcam
dump` output; the lane enters it into `mods/PLAYER/grug_mounts/catalog.lua`.

## Install

1. Use any world of the Grudgelands game (an existing one is fine: the probe
   writes nothing).
2. Copy this folder into the world as `worldmods/grug_r451_mc_probe`
   (Flatpak: `~/.var/app/org.luanti.luanti/.minetest/worlds/<world>/worldmods/grug_r451_mc_probe`).
3. Start the world. The log shows
   `[mountcam] loaded: /mountcam (0.45.1 riding camera probe, never shipped)`.
4. For the web build: the server the web client joins needs the same
   `worldmods` copy.

Changing values and `/mountcam try` need the `server` privilege
(singleplayer has it; on a server `/grant <name> server`). Reading the
values and `dump` need none.

**Remove the folder afterwards** (and restart): the values go back to the
shipped ones.

## Commands

All values are **nodes**. `y` is the height above the mount's feet; `z` is
along the mount, positive toward its head, negative toward its tail.

| Command | What it does |
|---|---|
| `/mountcam` | Shows the model you ride, its mesh, size and seat height, and its values. |
| `/mountcam <y> [<z>]` | First person: the camera height and its place along the mount (z stays as it is when left out). Example: `/mountcam 2.5 -0.3`. |
| `/mountcam third <y> [<z>]` | Third person: the point the camera looks over from behind (the rider's head). Example: `/mountcam third 2.3`. |
| `/mountcam reset` | The shipped values for the model you ride. |
| `/mountcam dump` | A ready-to-paste Lua table of every model you changed (also written to `debug.txt`, after every change too). |
| `/mountcam try <model>` | Mounts you on any model, whatever your faction, race and purchases (the summon's own rules still apply: flyers need flight ground, boats water). `/mountcam try` alone lists the models; `/mountcam try off` returns to your own mounts. |

A change applies at once and holds for every later ride this run. Models with
the same mesh and size share their values: the three horses (`t1_accord`,
`t1_throng`, `human`) change together.

Third person: the engine keeps the third-person point within 1 node below
and 1.5 nodes above the first-person height, and `z` within ±0.5; `/mountcam`
says when a value is clamped. It then pulls the camera back about 2.75 nodes
along your view (less in front of a wall).

## Models and shipped values

| Model | Mount | Seat (nodes) | First person y, z | Third person y, z |
|---|---|---|---|---|
| `t1_accord`, `t1_throng`, `human` | Courser, Highcourt Charger (horse) | 1.26 | 2.4, -0.2 | 2.15, 0 |
| `dwarf` | Frostbarrow Ibex | 1.23 | 2.1, -0.3 | 2.15, 0 |
| `elf` | Silverleaf Stag | 1.52 | 2.25, -0.1 | 2.4, 0 |
| `orc` | War Boar | 1.27 | 1.95, -0.3 | 2.15, 0 |
| `undead` | Grave Wolf | 1.43 | 2.1, -0.3 | 2.35, 0 |
| `troll` | Kezamba Tiger | 1.19 | 2.15, -0.2 | 2.1, 0 |
| `expert_accord` | Accord Eagle | 1.86 | 2.65, -0.2 | 2.75, 0 |
| `master_accord` | Steller's Sea Eagle | 2.56 | 3.4, -0.2 | 3.5, 0 |
| `expert_throng` | Throng Cave Bat | 1.92 | 2.6, -0.3 | 2.8, 0 |
| `master_throng` | Giant Blood Bat | 2.86 | 3.5, -0.4 | 3.75, 0 |
| `boat`, `improved_boat` | Rowboat, Sailboat | 0.1 | 0.8, 0 | 0.8, 0 |

Before 0.45.1 every land and flying mount had its first-person camera 1.1
nodes above its feet (inside a horse, at a flyer's feet), boats 0.8.

## What to look for

- First person: the mount's neck and head low in the view, the world in
  front; riding and flying usable (a slope, a turn, looking down to land).
- Third person: the rider and the mount from behind, not too low.
- Low openings: under a ceiling lower than the camera height the view goes
  into the ceiling node (the mount's body stays 1.6 high).
- The eagles hover in their perched pose (head up); flying they stretch out.
