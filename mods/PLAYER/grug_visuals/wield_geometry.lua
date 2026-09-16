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
-- 10. WHICH SIDE OF THE HAFT THE HEAD IS ON -- playtest round 5, 2026-09-16,
--    "the axe blades of the Dur Brannoc residents point the wrong way".
--
--    Sections 6 and 7 fix the sprite's LONG axis and leave its ROLL about that
--    axis to the single triple in section 7. That roll decides where the half
--    of the sprite that is not on the anti-diagonal ends up: the image's
--    up-left direction maps to bone (0, -1, 0), i.e. model +y, straight UP.
--
--    For most of the ladder this is unobservable, and that is measured rather
--    than assumed. Mirror a sprite about its own long axis -- exactly what
--    rolling it 180 degrees does in the world -- and compare silhouettes:
--
--      default_tool_*sword / *pick / *shovel                 100.0% overlap
--      grug_materials_tool_*pick / *shovel                   100.0% overlap
--      grug_gear_item_sword_* / _dagger_*                    100.0% overlap
--      default_stick                                         100.0% overlap
--      default_tool_*axe                                      26.3% overlap
--      grug_materials_tool_*axe                               26.3% overlap
--      grug_gear_item_greataxe_*                              17.4% overlap
--      grug_gear_item_staff_*                                 34.5% overlap
--
--    39 of the 63 sprites a character can hold are invariant; the tool counts
--    are printed by the script rather than quoted here, because the first
--    write-up of this section quoted a hand count and got it wrong.
--
--    A sword, a dagger, a pick, a shovel and a stick are drawn ON their own
--    long axis and cannot tell the two rolls apart. An AXE cannot be drawn that
--    way: its bit is a wide edge mounted ACROSS the end of the haft, and all
--    THREE axe families in the game -- minetest_game's four surviving hatchets,
--    `grug_materials`' four deep-tier ones (tools.lua, `groups = {axe = 1,
--    grug_equip_weapon = 1}`) and the generator's six greataxes, fourteen items
--    -- draw it on the image's up-left side, so through the section-7 roll the
--    cutting edge ends up pointing at the sky.
--
--    Which way it SHOULD point is not taste either, because this arm swings.
--    The `work` activity and every dig run `character.b3d`'s mine frames, which
--    rotate Arm_Right about its own local x (the fixture measures +114 degrees
--    at the peak, forward); the sprite's plane is the y-z plane, i.e. exactly
--    the plane the arm swings in. Follow the head through the downstroke: with
--    the head on the up side it is the axe's POLL that leads and the edge that
--    trails. Mirror it and the edge leads, which is what an axe is.
--
--    So the axe family gets the SAME transform rolled 180 degrees about the
--    blade. That roll is the entity-local map x <-> y, z -> -z, and composing
--    it into section 7's matrix gives, again uniquely,
--
--      **x = 90, y = -(45 - t), z = -90**
--
--    -- the sprite's own 45 changing sign against the tilt, because the mirror
--    negates the in-plane roll while leaving the long axis where it was. The
--    POSITION does not move at all: the grip pixel lies on the anti-diagonal,
--    which the mirror fixes point by point, so `R * GRIP` is the same vector.
--
--    This is a statement about ART, not about items, so it is dispatched by
--    GROUP (`axe`) exactly as the diagonal/upright split is -- both tables are
--    a few lines below, because they ARE the convention and a fixture with no
--    engine has to be able to read them -- and it reaches the player's own axe
--    through the same seam as an NPC's.
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

-- The three poses, and nothing else may name one. `POSE.tool` is the diagonal
-- tool convention of sections 6 and 7; `POSE.edge_down` is that same transform
-- rolled 180 degrees about the blade for art whose working edge is drawn off
-- the long axis (section 10); `POSE.upright` is the anonymous-icon pose below.
local POSE = {
	tool = "tool",
	edge_down = "edge_down",
	upright = "upright",
}
grug_visuals.POSE = POSE

-- WHICH POSE A PIECE OF ART ASKS FOR, by GROUP (project convention: dispatch
-- on groups, never on a name list). It lives here rather than next to the
-- engine code because it IS the sprite convention -- the same statement
-- sections 6, 7 and 10 make, in the vocabulary an item definition can carry --
-- and because a fixture with no engine has to be able to read it.
--
-- `DIAGONAL` is every family drawn in the diagonal tool convention: each
-- `default` tool carries one of the first four, every grug_gear weapon carries
-- `sword`/`axe`/`staff` plus `grug_equip_weapon`, and the fishing rod carries
-- `fishing_rod` -- VoxeLibre draws that sprite on the same anti-diagonal with
-- the grip at the bottom-left, with the LINE and bobber hanging off the
-- down-right side, so the plain tool pose is what makes the line hang down.
-- A new family joins by declaring its group, the same way it joins the weapon
-- slot; anything that declares none -- `mobs:lasso`, a torch, an apple, an
-- ability orb -- is an anonymous icon and gets `POSE.upright` with no
-- exception list.
--
-- `EDGE_DOWN` is the subset of those whose working edge is drawn OFF the long
-- axis and therefore has a side (section 10). It is checked first, so a
-- greataxe -- `axe` and `grug_equip_weapon` -- lands in the rolled pose.
local DIAGONAL_GROUP = {"sword", "axe", "pickaxe", "shovel", "staff",
	"fishing_rod", "grug_equip_weapon"}
local EDGE_DOWN_GROUP = {"axe"}
grug_visuals.DIAGONAL_GROUP = DIAGONAL_GROUP
grug_visuals.EDGE_DOWN_GROUP = EDGE_DOWN_GROUP

-- `group_value(itemname, group)` is `core.get_item_group` in the engine and a
-- table lookup in the fixture. Passed in rather than closed over so that the
-- once-a-second wield poll allocates nothing.
function grug_visuals.pose_for(itemname, group_value)
	for _, group in ipairs(EDGE_DOWN_GROUP) do
		if (group_value(itemname, group) or 0) > 0 then
			return POSE.edge_down
		end
	end
	for _, group in ipairs(DIAGONAL_GROUP) do
		if (group_value(itemname, group) or 0) > 0 then
			return POSE.tool
		end
	end
	return POSE.upright
end

-- The attachment for a parent whose (uniform) stature scale is `stature`.
-- nil / 0 means "do not compensate" -- the weapon then scales with its wielder.
--
-- `pose` is one of `grug_visuals.POSE`; nil means `tool`. There are exactly
-- three because there are exactly three kinds of held art. Sections 6 and 7
-- derive the hand from the diagonal tool convention: the weapon runs along the
-- image's anti-diagonal and the grip is a specific pixel on it. Section 10 adds
-- the roll for the one family that cannot be drawn on that diagonal. A torch,
-- an apple, a sapling or a bag is neither: it is a node item or a craftitem
-- drawn as an ordinary upright icon, with no diagonal and no grip pixel -- run
-- through the tool transform it comes out floating a quarter of a node in front
-- of the fist and rolled 45 degrees, because both the offset and the roll are
-- the sprite diagonal's.
--
-- So a non-tool is held the only way an anonymous icon can be: its CENTRE in
-- the fist (`pos = HAND`, no grip offset -- the image has no privileged point)
-- and its own up standing up. Asking, in bone-local terms, for
--
--   image up (entity +y) -> (0, -1, 0)   = model +y, up
--   the flat's normal    -> (1, 0, 0)    = model -x, sideways, as the blade's
--
-- gives the unique triple **x = 90, y = -90, z = 90** -- the same x and z as
-- the tool pose, which is the reassuring part: only the sprite's own built-in
-- angle differs.
function grug_visuals.wield_transform(stature, pose)
	local k = tonumber(stature)
	if not k or k <= 0 then
		k = 1
	end
	local size = SIZE / k
	local sprite_edge = 40 * size / 2
	-- LOUD, not lenient. The second argument was a BOOLEAN before playtest
	-- round 5 (`true` meant upright), and a stale `true` coerced to the default
	-- would hand back the TOOL pose -- the sprite a quarter of a node in front
	-- of the fist and rolled 45 degrees, silently, for as long as nobody looked.
	-- nil stays legal and means `tool`; anything else is a caller bug.
	if pose == nil then
		pose = POSE.tool
	elseif pose ~= POSE.tool and pose ~= POSE.edge_down and
			pose ~= POSE.upright then
		error("grug_visuals.wield_transform: unknown pose " .. tostring(pose), 2)
	end

	if pose == POSE.upright then
		return {
			bone = BONE,
			pos = {x = HAND.x, y = HAND.y, z = HAND.z},
			rot = {x = 90, y = -90, z = 90},
			size = {x = size, y = size},
			pose = pose,
			stature = k,
			base_size = SIZE,
			tilt_up = TILT_UP,
			hand = HAND,
			sprite_edge = sprite_edge,
			-- The centre IS the anchor: an icon nobody drew a grip into has no
			-- better point to hang from.
			grip_fraction_x = 0,
			grip_fraction_y = 0,
		}
	end

	local tilt = TILT_UP * DEG
	local blade_y = -math.sin(tilt)
	local blade_z = math.cos(tilt)
	-- The image's two in-plane axes in bone coordinates (section 7's x and y
	-- columns), so the position below is read off the same matrix the rotation
	-- is: image +x -> s*(B - E2), image +y -> s*(B + E2), with
	-- E2 = N x B = (1,0,0) x (0, -sin t, cos t) = (0, -cos t, -sin t).
	-- In terms of the two numbers above that is (0, -blade_z, blade_y), since
	-- blade_y is itself -sin t. (This line read `-blade_y` until the round-2
	-- review: inert at TILT_UP = 0 and with the grip on the anti-diagonal,
	-- wrong for any other tilt or grip point.)
	local e2_y, e2_z = -blade_z, blade_y
	local ux_y = ROOT_HALF * (blade_y - e2_y)
	local ux_z = ROOT_HALF * (blade_z - e2_z)
	local uy_y = ROOT_HALF * (blade_y + e2_y)
	local uy_z = ROOT_HALF * (blade_z + e2_z)

	-- Section 10's roll is the entity-local map x <-> y, z -> -z, so in bone
	-- coordinates it simply SWAPS the two in-plane axes above. Writing it that
	-- way rather than reusing the tool position is not decoration: with the grip
	-- on the anti-diagonal (gx == gy) the two agree exactly, and the day a
	-- sprite convention moves the grip off it they would not.
	local ax_y, ax_z, ay_y, ay_z = ux_y, ux_z, uy_y, uy_z
	-- The unique Euler triple for the rolled pose is x = 90, y = -(45 - t),
	-- z = -90: the mirror leaves the long axis (and therefore the tilt) where it
	-- was but negates the in-plane roll, which is why the TILT sign flips with
	-- the z rather than the 45 doing so.
	local tilt_sign = 1
	local spin = 90
	if pose == POSE.edge_down then
		ax_y, ax_z, ay_y, ay_z = uy_y, uy_z, ux_y, ux_z
		tilt_sign = -1
		spin = -90
	end

	local gx = GRIP_FRACTION_X * sprite_edge
	local gy = GRIP_FRACTION_Y * sprite_edge

	return {
		bone = BONE,
		pos = {
			x = HAND.x,
			y = HAND.y - (gx * ax_y + gy * ay_y),
			z = HAND.z - (gx * ax_z + gy * ay_z),
		},
		rot = {x = 90, y = -(45 + tilt_sign * TILT_UP), z = spin},
		size = {x = size, y = size},
		pose = pose,
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
