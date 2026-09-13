# WP40 quality follow-up: natural ore persistence

Status: implementation on `wp40-quality-ore`, 2026-09-13.

`docs/design/world.md` rule R4, decided 2026-08-08, makes ordinary natural
resources finite: a successfully harvested or shattered natural ore remains
air. Unbounded depth supplies replacement deposits through exploration; no
global dig hook may turn an ordinary ore into a timed renewable node. The
protected functional sockets reserved for future mining camps are a separate
world-structure mechanism. The retired `grug_nodes:depleted_vein` node, global
dig hook, timers and ore-respawn loader are absent.

This correction targets fresh worlds only. There is no saved-world migration or
compatibility registration for the placeholder used by the earlier in-progress
implementation.

The focused WP43 integration fixture covers every one of the 15 natural
resources, ordinary harvesting and every possible shatter tier. It also asserts
that successful transactions leave air without starting a timer, and that the
retired hook, node, loader and source file remain absent.
