--
-- WHERE THE VISIBLE WEAPON SITS IN THE RIGHT HAND -- the five numbers, and the
-- derivation they come out of. Nothing else in the game may hold a copy.
--
-- Playtest round 1 (2026-09-15) replaced the first, eyeballed version: the user
-- photographed a guard from behind and the sword's TIP was in the hand with the
-- HILT sticking straight out backwards. The old numbers
-- (pos = {0, 5.5, -1.5}, rot = {-90, 180, 0}) put the sprite's CENTRE 1.5 units
-- behind the fist, which is exactly that picture -- the derivation below
-- reproduces it to three decimals, which is why it is trusted for the fix.
--
-- Pure Lua, no engine: `tools/wp13/wield_transform_kat.lua` loads this very
-- file and re-derives the geometry independently.
--
-- ---------------------------------------------------------------------------
-- 1. UNITS. A mesh is authored at 10 units = 1 node, and `set_attach`
--    positions use the same scale ("Attachments", lua_api.md:8874). Everything
--    below is in those model units.
--
-- 2. THE BONE FRAME, read out of `mods/BASE/player_api/models/character.b3d`
--    (its NODE chunks, not guessed):
--
--      Body       pos (0, 6.3, 0)      quat w=0 y=1  = 180 deg about y
--      Arm_Right  pos (-3.15, 5.25, 0) quat w=0 x=1  = 180 deg about x
--
--    Composed, Ry(180) * Rx(180) = Rz(180) = diag(-1, -1, 1). Both factors are
--    half turns and therefore symmetric matrices, so Irrlicht's transposed
--    quaternion convention (`quaternion::getMatrix_transposed`, used by
--    `core::Transform::buildMatrix`) cannot change the answer. The bone's own
--    axes, expressed in model space:
--
--      bone +x -> model -x   (the character's LEFT)
--      bone +y -> model -y   (DOWN, i.e. along the hanging arm to the hand)
--      bone +z -> model +z   (FORWARD, the way the character faces)
--
--    The joint's origin lands at model (3.15, 11.55, 0) -- the shoulder.
--
-- 3. WHICH WAY IS FORWARD is not a guess either: of the six head quads, the one
--    whose UV rectangle is the skin's face (pixels 8..16 x 8..16 of the 64x32
--    layout -- the rectangle that actually carries the two eye pixels) has the
--    geometric normal +z. The back-of-head quad (24..32) has -z. The
--    `Arm_Right`-weighted vertices sit at model x 2.1..4.2, so model +x is the
--    character's own right.
--
-- 4. WHERE THE HAND IS. The `Arm_Right`-weighted vertices span model
--    y 6.3..12.6 with the joint at y 11.55, so the arm reaches 5.25 units past
--    the joint -- bone-local y = +5.25 is the far end. The skin covers those
--    6.3 units with 12 texture pixels and the fist is the bottom 4 of them,
--    i.e. the last 2.1 units: bone-local y 3.15..5.25, centre **4.2**.
--
-- 5. HOW A WIELDITEM IS ORIENTED. `createExtrusionMesh`
--    (src/client/wieldmesh.cpp:43) builds a unit quad with image u along the
--    entity's local +x and image v along local -y (so image TOP is local +y),
--    0.1 thick in z, then scales it by 40 (`WIELD_SCALE_FACTOR_EXTRUDED`) and
--    by `visual_size / 2` (content_cao.cpp:756). One sprite edge is therefore
--    `40 * size / 2` model units long and the image's up direction is the
--    entity's +y.
--
-- 6. WHERE THE GRIP IS IN THE IMAGE. Every grug_gear weapon sprite is drawn
--    handle-at-the-bottom, business-end-at-the-top, long axis vertical:
--    sword grip rows 11..15 (crossguard 9..10), greataxe shaft rows 11..15,
--    dagger grip rows 10..13, staff shaft down to row 15. Row 13 of 16 is the
--    middle of the sword's and the greataxe's grip and one row below the
--    dagger's. Image v runs 0 at the top edge to 1 at the bottom, so that row's
--    CENTRE is v = 13.5/16 and the sprite-local offset from the centre is
--    `GRIP_FRACTION = 0.5 - 13.5/16 = -5.5/16` of a sprite edge.
--
-- 7. THE ROTATION. `set_attach`'s rotation is Irrlicht Euler degrees applied as
--    Rz(z) * Ry(y) * Rx(x), right-handed about the BONE's axes
--    (`matrix4::setRotationRadians`, used by `GenericCAO::updateAttachments`,
--    content_cao.cpp:1468). With a tilt of `t` degrees above level we want, in
--    bone-local terms:
--
--      entity +y (the blade)  -> (0, -sin t,  cos t)  = forward, t above level
--      entity +x (the guard)  -> (0,  cos t,  sin t)  = down-forward
--      entity +z (the flat)   -> (1, 0, 0)            = model -x, sideways
--
--    The flat facing sideways is what makes the blade read as VERTICAL (the
--    crossguard, which lies in the plane of the flat, then stands upright);
--    the old numbers had it facing straight down, i.e. the blade held flat.
--    The unique Euler triple for those three columns is
--    **x = 90, y = -t, z = 90** -- the old orientation turned 90 degrees about
--    its own long axis, plus the tilt.
--
-- 8. THE POSITION is then forced, not tuned: the entity's origin is the
--    sprite's centre, so
--
--      pos = HAND - (GRIP_FRACTION * SPRITE_EDGE) * blade_direction
--
--    which puts the grip centre exactly in the fist and leaves the pommel
--    0.7 units behind it.
--
-- The printed check (`tools/wp13/wield_transform_kat.lua`), arm hanging,
-- offsets from the fist: hilt (0, -0.178, -0.664), grip (0, 0, 0),
-- tip (0, +0.961, +3.586), blade direction (0, 0.259, 0.966).
--
-- One thing this cannot decide without a client: with the flat vertical the
-- blade lies in the sagittal plane, so the default over-the-shoulder camera sees
-- it edge-on. `rot.z` is the constant that trades that against a flat-held blade
-- (90 as shipped, 0 for horizontal); it is NOT free of the rest -- changing it
-- rolls the blade about its own axis and leaves the grip where it is.
--

-- The bone the entity hangs off.
local BONE = "Arm_Right"

-- visual_size of the wielditem entity. It is a LENGTH as much as a size: it
-- scales SPRITE_EDGE below and therefore moves the position too, which is why
-- the position is computed rather than written down.
local SIZE = 0.22

-- Degrees the blade rides above level. "Slightly up": 15 keeps the tip clear
-- of the leg on a hanging arm without reading as a salute.
local TILT_UP = 15

-- Centre of the fist, in bone-local units (section 4).
local HAND = {x = 0, y = 4.2, z = 0}

-- Sprite geometry (sections 5 and 6).
local SPRITE_EDGE = 40 * SIZE / 2
local GRIP_FRACTION = -5.5 / 16

local blade_y = -math.sin(TILT_UP * math.pi / 180)
local blade_z = math.cos(TILT_UP * math.pi / 180)
local grip = GRIP_FRACTION * SPRITE_EDGE

-- Read-only. `apply.lua` is the only consumer in the game; the KAT reads it so
-- the fixture and the engine can never be checking different numbers.
grug_visuals.WIELD = {
	bone = BONE,
	pos = {
		x = HAND.x,
		y = HAND.y - grip * blade_y,
		z = HAND.z - grip * blade_z,
	},
	rot = {x = 90, y = -TILT_UP, z = 90},
	size = {x = SIZE, y = SIZE},
	-- The inputs, published for the fixture and for the next round of
	-- eyeballing: change one of these, not the results above.
	tilt_up = TILT_UP,
	hand = HAND,
	sprite_edge = SPRITE_EDGE,
	grip_fraction = GRIP_FRACTION,
}
