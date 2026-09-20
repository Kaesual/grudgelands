# Capital services checks

`geometry_micro.lua`, `services_micro.lua`, `purchase_micro.lua` and
`furnace_micro.lua` are bounded importable real-production checks. The global
WP40 final runner owns their single frozen PUC/LuaJIT pair. Development uses
LuaJIT only. Six complete capital geometries and the real manifest constructor
remain in the existing WP13/R8-ALCH LuaJIT tests.

`render.sh /absolute/fresh/output` reconstructs real service plots and catalog
stand poses, checks their clearance, and creates native Blender diagnostics.
It requires LuaJIT, Python with NumPy/Pillow, and Blender. Runtime meshes use
catalog texture slots and full visual scale; B3D key frames follow the pinned
loader's file-frame-minus-one rule. The raw B3D UV V coordinate is flipped once
for Blender image sampling. Eevee avoids the horse mesh's coplanar duplicate
triangle artifacts observed in the superseded Cycles attempt.

The clearance test compares conservative full posed envelopes against every
actual emitted non-air cell cube, including roofs, rails and troughs, with a
0.01-node margin. It checks neighboring displays and the trainer/front aisle,
and verifies production grounding constants against all twelve evaluated models.
The render evaluator is offline evidence, not a replacement for the integrated
engine/user visual gate. Pinned source paths are cited in `b3d_pose.py`.

Cutaways omit roof cells at/above y=4, underground cells and the front wall to
show furnishings. Trainer bars mark actual socket positions; they are not NPC
skins. Gear cards/contact sheet use actual registered item artwork; they are
not a simulation of the engine's wielditem extrusion. Display entities use the
actual item names in production. Mount images show the complete stand silhouette.

Earlier callback evidence is a separately reviewed immutable checkpoint. Final
geometry/display evidence and hashes supersede it only for the changed inputs;
the final integrated interpreter pair and engine fleet remain root-owned gates.
