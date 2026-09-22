# Round 16 atlas repair and service markers

Implementer: root Astra. Independent review pending; GUI acceptance pending.

## Cause and change

The prior atlas emitted `size[]` with no `formspec_version[]`, so engine v1
legacy sorting applied despite page-local real coordinates. Engine
`guiFormSpecMenu.cpp:3495` sorts buttons at priority zero and images at one;
the opaque atlas image therefore draws over the player/party and quest buttons.
The personal debug log confirms heading textures reached the client, and all
32 heading PNGs contain nontransparent artwork. This was not missing media.

The atlas now starts with formspec version 3 and explicitly opts back into
legacy sizing/navigation coordinates before switching its own content to real
coordinates. Engine `guiFormSpecMenu.cpp:3295` consumes that initial coordinate
directive before form sizing. This preserves wrapper geometry while using
definition-order drawing, with the map before all markers. Other pages are
unchanged. Existing 16-direction media and open-only live updates remain.

Quest providers now emit one marker per giver with names-only tooltips. There
is no grouping or proximity behavior. Authored sockets provide profession and
Riding trainers plus kings; their names use the same profession/entity definitions
as the live NPCs. A narrow `grug_mobs.dragon_map_markers()` read API returns
copies of the existing dragon locations/names, without loading entities or
consulting encounter state. Existing book, riding and crown artwork is reused;
no new media or external asset imports. Boss icons mark locations, not life state.

## Evidence

`tools/r16_map/kat.lua` runs the actual shared inventory wrapper, atlas geometry,
providers and page under isolated engine stubs. LuaJIT development pass covers
version/coordinate ordering, individual nearby givers, static services, names,
region clipping, party disconnect, direction updates, stable selection and
open/close/death cleanup. The final compact interpreter run belongs to root's
combined round gate. These are server formspec/source checks, not rendered GUI
evidence; final visibility/readability and hovering remain the user's playtest.
