--
-- WHERE THE VISIBLE WEAPON SITS IN THE RIGHT HAND -- the numbers, and the
-- derivation they come out of. Nothing else in the game may hold a copy.
--
-- Third version. Round 1 (2026-09-15) fixed a sword held by the tip; this one
-- (playtest round 2, same day) follows the two rulings that came out of seeing
-- it in a client -- **the blade points straight forward, 90 degrees to the arm
-- (tilt 0)**, and **the weapon is the same weapon on every race** -- and the
-- one change under it: since the whole game now uses minetest_game's DIAGONAL
-- sprite convention (grip bottom-left, tip top-right) instead of the vertical
-- one grug_gear used to, the sprite's long axis is no longer its local +y.
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
--    `40 * size / 2` model units long.
--
-- 6. WHERE THE GRIP IS IN THE IMAGE -- and this is what changed. Every held
--    item in the game is now drawn in ONE convention: 16x16, long axis on the
--    image's ANTI-DIAGONAL, grip bottom-left, business end top-right. That is
--    minetest_game's own tool convention (`default_tool_steelsword.png` and
--    the three tool families), it is what `tools/wp13/gen_weapon_ladder.py`
--    generates every sword, dagger, greataxe, staff, pick, axe and shovel in,
--    and it is why there is still exactly ONE transform.
--
--    The fist sits at image pixel (3.4, 12.6), measured as the centroid of the
--    WOODEN handle pixels of `default_tool_steelsword.png` -- the eleven
--    non-grey pixels at (3,10) (3,11) (4,11) (2..5,12) (1..3,13) (2,14), whose
--    pixel centres average to (3.41, 12.59). The generator asserts that every
--    sprite it writes has an opaque pixel there.
--
--    In the entity's own frame (image u along +x, image v along -y, origin at
--    the sprite's centre) that point is
--
--      GRIP = ((u/16 - 0.5) * EDGE, (0.5 - v/16) * EDGE, 0)
--           = (-0.2875 * EDGE, -0.2875 * EDGE, 0)
--
--    -- equal in both components, because (3.4, 12.6) lies on the image's
--    anti-diagonal, i.e. exactly on the weapon's own long axis. The offset is
--    therefore purely along the blade, which is what makes a pommel stick out
--    behind the fist rather than out of its side.
--
-- 7. THE ROTATION. `set_attach`'s rotation is Irrlicht Euler degrees applied as
--    Rz(z) * Ry(y) * Rx(x), right-handed about the BONE's axes
--    (`matrix4::setRotationRadians`, used by `GenericCAO::updateAttachments`,
--    content_cao.cpp:1468). The sprite's long axis is the image anti-diagonal,
--    i.e. the entity-local direction (1, 1, 0)/sqrt(2). Asking, in bone-local
--    terms, for
--
--      the blade      -> (0, -sin t, cos t)   forward, t degrees above level
--      the flat's     -> (1, 0, 0)            model -x: the flat faces
--      normal                                 sideways, so the blade's broad
--                                             face stands vertical
--
--    fixes the whole rotation, and the unique Euler triple that produces it is
--
--      **x = 90, y = -(45 + t), z = 90**
--
--    The 45 is the sprite's own built-in diagonal; the previous, vertically
--    drawn sprites were the t = 0 case of the same formula with the 45 absent.
--    (Derivation: with s = sin45 = cos45, the images of the entity's basis
--    vectors are x -> s*(B - E2), y -> s*(B + E2), z -> (1,0,0), where
--    B = (0,-sin t, cos t) and E2 = (1,0,0) x B = (0,-cos t,-sin t). Reading
--    the standard Rz*Ry*Rx form off those three columns gives -sin y =
--    s*(cos t + sin t) = sin(45 + t), sin x = 1 and sin z = 1.)
--
-- 8. THE POSITION is then forced, not tuned: the entity's origin is the
--    sprite's centre, so
--
--      pos = HAND - R * GRIP
--
--    which puts the grip exactly in the fist. With the grip on the long axis
--    this collapses to a pure offset along the blade.
--
-- 9. STATURE. `set_attach` parents the entity's matrix node to the parent's
--    JOINT NODE (content_cao.cpp:1462-1470), and the parent's own
--    `visual_size` is on the animated mesh node above that joint
--    (content_cao.cpp:705). So the absolute transform of the sprite is
--
--      S_parent * T(pos) * R(rot) * S_child
--
--    Both the attachment position and the sprite's geometry therefore get
--    S_parent. The position half is harmless -- S_parent is linear, so
--    S_parent(HAND - R*GRIP) still lands on S_parent(HAND), the real fist of
--    the scaled model. The GEOMETRY half is not: with a non-uniform S_parent
--    the sprite is stretched along one model axis and squashed along another,
--    and because this sprite's long axis is a DIAGONAL of its own quad, that
--    stretch tilts the blade and changes its length. That is the defect the
--    player reported -- the same sword reading longer, thinner and tipped down
--    on a player, while the 1:1-scaled guards looked right.
--
--    It cannot be cancelled by the child's `visual_size`. Cancelling needs
--    S_child = SIZE * R^-1 * S_parent^-1 * R to be DIAGONAL, and with this R
--    that holds only when the parent's y scale equals its horizontal scale.
--    So the fix is upstream of here and lives in `compose.lua`: **race stature
--    is now one scalar per race**, not an (x, y, z) triple. With S_parent =
--    k * I the cancellation is exact and trivial --
--
--      size = SIZE / k
--
--    -- and the position, computed from that size, follows. The weapon is then
--    the same absolute weapon in every hand. Feed `stature` = nil (mobs) and
--    nothing is compensated: a mob's scale is its real size, and an elite
--    guard twice the height should carry a sword twice the size.
--
-- The printed check is `tools/wp13/wield_transform_kat.lua`.
--
-- THE TWO TASTE VALUES, both in this file and nowhere else: `SIZE` (how big
-- the weapon is) and `TILT_UP` (how far above level the blade rides, 0 = the
-- ruling's "straight forward, 90 degrees to the arm"). `GRIP` is measurement,
-- not taste, and moves only if the sprite convention moves.
--

-- The bone the entity hangs off.
local BONE = "Arm_Right"

-- The sprite's edge length as a fraction of a node, before any stature
-- compensation. 0.32 is playtest round 2's ruling (~150% of round 1's 0.22);
-- at 16 px that is 6.4 model units across the square, so the blade itself --
-- the anti-diagonal of the sprite -- reads about 8 units long against a 6.3
-- unit arm.
local SIZE = 0.32

-- Degrees the blade rides above level. 0 = straight forward, at a right angle
-- to the hanging arm (playtest round 2).
local TILT_UP = 0

-- Centre of the fist, in bone-local units (section 4).
local HAND = {x = 0, y = 4.2, z = 0}

-- Where the fist grips the sprite, in image pixels of the shared 16x16
-- convention (section 6).
local GRIP_U, GRIP_V = 3.4, 12.6
local SPRITE_PIXELS = 16

-- Image-space fractions of one sprite edge, measured from the sprite's centre:
-- +x is image right, +y is image UP (the entity's own +y).
local GRIP_FRACTION_X = GRIP_U / SPRITE_PIXELS - 0.5
local GRIP_FRACTION_Y = 0.5 - GRIP_V / SPRITE_PIXELS

local DEG = math.pi / 180
local ROOT_HALF = math.sqrt(0.5)

-- The attachment for a parent whose (uniform) stature scale is `stature`.
-- nil / 0 means "do not compensate" -- the weapon then scales with its wielder.
function grug_visuals.wield_transform(stature)
	local k = tonumber(stature)
	if not k or k <= 0 then
		k = 1
	end
	local size = SIZE / k
	local sprite_edge = 40 * size / 2

	local tilt = TILT_UP * DEG
	local blade_y = -math.sin(tilt)
	local blade_z = math.cos(tilt)
	-- The image's two in-plane axes in bone coordinates (section 7's x and y
	-- columns), so the position below is read off the same matrix the rotation
	-- is: image +x -> s*(B - E2), image +y -> s*(B + E2), with
	-- E2 = (0, -cos t, -sin t).
	local e2_y, e2_z = -blade_z, -blade_y
	local ux_y = ROOT_HALF * (blade_y - e2_y)
	local ux_z = ROOT_HALF * (blade_z - e2_z)
	local uy_y = ROOT_HALF * (blade_y + e2_y)
	local uy_z = ROOT_HALF * (blade_z + e2_z)

	local gx = GRIP_FRACTION_X * sprite_edge
	local gy = GRIP_FRACTION_Y * sprite_edge

	return {
		bone = BONE,
		pos = {
			x = HAND.x,
			y = HAND.y - (gx * ux_y + gy * uy_y),
			z = HAND.z - (gx * ux_z + gy * uy_z),
		},
		rot = {x = 90, y = -(45 + TILT_UP), z = 90},
		size = {x = size, y = size},
		-- The inputs, published for the fixture and for the next round of
		-- eyeballing: change one of these, not the results above.
		stature = k,
		base_size = SIZE,
		tilt_up = TILT_UP,
		hand = HAND,
		sprite_edge = sprite_edge,
		grip_fraction_x = GRIP_FRACTION_X,
		grip_fraction_y = GRIP_FRACTION_Y,
	}
end

-- The uncompensated attachment (a 1:1 wielder), kept as a named value because
-- the fixture and every reader want one concrete set of numbers to look at.
grug_visuals.WIELD = grug_visuals.wield_transform(1)
