# WP40 quality follow-up: natural ore persistence

Status: implementation on `wp40-quality-ore`, 2026-09-13.

`docs/design/world.md` rule R4, decided 2026-08-08, makes ordinary natural
resources finite: a successfully harvested or shattered natural ore remains
air. Unbounded depth supplies replacement deposits through exploration; no
global dig hook may turn an ordinary ore into a timed renewable node. The
protected functional sockets reserved for future mining camps are a separate
world-structure mechanism and do not use `grug_nodes:depleted_vein`.

Older saved worlds can still contain `grug_nodes:depleted_vein`. Its retained
registration is hidden from the creative inventory, drops nothing and removes
only that exact node through either its old node timer or one named, non-repeating
LBM. The engine runs such a named LBM only when its introduction timestamp is
newer than the activated mapblock
(`reference_projects/luanti/doc/lua_api.md:10264-10282`). Legacy metadata is
ignored. Both callbacks re-check the live node identity, so a repeated callback
or a stale timer cannot remove a replacement node. They
use `core.remove_node`, which the pinned Luanti API documents as equivalent to
setting air but faster (`reference_projects/luanti/doc/lua_api.md:6905-6906`);
the C++ binding returns the result of `ServerEnvironment::removeNode`
(`reference_projects/luanti/src/script/lua_api/l_env.cpp:219-228`).

The focused WP43 integration fixture covers every one of the 15 natural
resources, ordinary harvesting, every possible shatter tier, valid/invalid/
empty old metadata, timer and LBM cleanup, repeated callbacks and a replacement
node at a stale callback position. No old placeholder restores ore or stone.
