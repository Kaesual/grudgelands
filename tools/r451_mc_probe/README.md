# 0.45.1 probe: the riding camera, seat and size (`/mountcam`)

A throwaway mod (`grug_r451_mc_probe`) for tuning where the camera sits while
riding, where the rider sits on the mount and how big the mount is (0.45.1 fix
plan row 8 and its playtest follow-ups). It is **never shipped**: nothing in
`mods/` depends on it, and the game runs exactly as before without it. It
changes the values of the mount model you ride **at runtime, for this server
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

Changing values (camera, seat, scale, reset) and `/mountcam try` need the `server` privilege
(singleplayer has it; on a server `/grant <name> server`). Reading the
values and `dump` need none.

**Remove the folder afterwards** (and restart): the values go back to the
shipped ones.

## Commands

All values are **nodes**. `y` is the height above the mount's feet; `z` is
along the mount, positive toward its head, negative toward its tail; `x` is
sideways, positive to the rider's right.

| Command | What it does |
|---|---|
| `/mountcam` | Shows the model you ride: its mesh, its size (and the factor of the shipped size), the seat and the camera. |
| `/mountcam <y> [<z>]` | First person: the camera height and its place along the mount (z stays as it is when left out). Example: `/mountcam 2.5 -0.3`. |
| `/mountcam third <y> [<z>]` | Third person: the point the camera looks over from behind (the rider's head). Example: `/mountcam third 2.3`. |
| `/mountcam seat <y> [<z> [<x>]]` | Where the rider sits on the mount: y above the mount's feet, z toward its head, x to the right (z and x stay as they are when left out). The mount is summoned again in place. The camera does not move with it. Example: `/mountcam seat 1.5 0 0.05`. |
| `/mountcam scale <factor>` | The mount's size, as a factor of the shipped size (`1` = as shipped, 0.3 to 3). The seat height and the seat's z and x grow with it; the camera stays. The mount is summoned again in place. Example: `/mountcam scale 1.1`. |
| `/mountcam reset` | The shipped camera, seat and size for the model you ride. |
| `/mountcam dump` | A ready-to-paste Lua table of every model you changed: size, seat (`attach_y`, `attach_z`, `attach_x` as the catalogue stores them, with the seat in nodes as a comment) and camera. Also written to `debug.txt` after every change. |
| `/mountcam try <model>` | Mounts you on any model, whatever your faction, race and purchases (the summon's own rules still apply: flyers need flight ground, boats water). `/mountcam try` alone lists the models; `/mountcam try off` returns to your own mounts. |

A camera change applies at once; a seat or size change re-summons the mount
under you. Both hold for every later ride this run. Models with the same mesh
and shipped size share their values: the three horses (`t1_accord`,
`t1_throng`, `human`) change together.

Third person: the engine keeps the third-person point within 1 node below
and 1.5 nodes above the first-person height, and `z` within ±0.5; `/mountcam`
says when a value is clamped. It then pulls the camera back about 2.75 nodes
along your view (less in front of a wall).

## Models and shipped values

Shipped after the playtests (follow-ups 3 to 5, the user's tuned values). Size is the catalogue's
`visual_size`; seat y is the rider's height above the mount's feet.

| Model | Mount | Size | Seat y (nodes) | First person y, z | Third person y, z |
|---|---|---|---|---|---|
| `t1_accord`, `t1_throng`, `human` | Courser, Highcourt Charger (horse) | 3 | 1.26 | 2.4, -0.2 | 2.15, 0 |
| `dwarf` | Frostbarrow Ibex | 1.45 | 1.23 | 2.8, -0.3 | 2.15, 0 |
| `elf` | Silverleaf Stag | 9.6 (was 8) | 1.32 (was 1.52) | 2.35, -0.1 | 2.25, 0 |
| `orc` | War Boar | 1.55 | 1.14 (was 1.27) | 1.95, -0.3 | 2.15, 0 |
| `undead` | Grave Wolf | 2.125 (was 1.7) | 1.78, z -0.31 (was 1.43) | 2.5, -0.3 | 2.35, 0 |
| `troll` | Kezamba Tiger | 1.45 | 1.52 (was 1.19) | 2.4, -0.2 | 2.4, 0 |
| `expert_accord` | Accord Eagle | 3 | 1.86, x 0.065 | 2.8, -0.2 | 2.75, 0 |
| `master_accord` | Steller's Sea Eagle | 4 | 2.56, x 0.087 | 3.6, -0.2 | 3.5, 0 |
| `expert_throng` | Throng Cave Bat | 5.07 (was 3) | 2, z -0.2 (was 1.92) | 3.8, -0.4 | 3.4, 0 |
| `master_throng` | Giant Blood Bat | 7.098 (was 4.2) | 3, z -0.3 (was 2.86) | 5, -0.5 | 4.6, 0 |
| `boat` | Rowboat | 1.078 (was 1) | 0.2, z -0.4 | 1, 0.2 | 0.8, 0 |
| `improved_boat` | Sailboat | 0.88 (was 1) | 0.09, z -0.2 | 1, -0.2 | 0.8, 0 |

Before 0.45.1 every land and flying mount had its first-person camera 1.1
nodes above its feet (inside a horse, at a flyer's feet), boats 0.8.

## What to look for

- First person: the mount's neck and head low in the view, the world in
  front; riding and flying usable (a slope, a turn, looking down to land).
- Third person: the rider and the mount from behind, not too low.
- Low openings: under a ceiling lower than the camera height the view goes
  into the ceiling node (the mount's body stays 1.6 high).
- Flyers: the flight loop in the air, a still level frame on the ground.
- The ridden ibex idles still (no head bob); its horns stay below the camera.
- The mount's size and the rider on its back, centred (`/mountcam scale`,
  `/mountcam seat`).
