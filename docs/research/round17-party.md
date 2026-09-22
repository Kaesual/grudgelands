# Round 17 party health colors

The Group page now has a personal `Health colors` dropdown above the pending
invitations list. It occupies the previously unused top-right row and does not
move or overlap either roster, invitation actions or party controls. Its two
validated values are `All green` and `By class`.

The preference is stored in player metadata under
`grug_parties:health_colors`. Missing or invalid stored values resolve to the
default `all_green`; submissions accept only the two internal values. Changing
it emits the existing preference refresh for that player and leaves invitation,
membership and HUD-visibility state untouched.

| Mode/class | Fill color |
|---|---|
| All green | `#4CAF50` |
| Warrior | `#A66A3F` brown |
| Mage | `#4A9BD8` blue |
| Priest | `#F2F2F2` white |
| Scout | `#6B7D32` dark olive-green |
| Empty/offline track | existing `#141414` dark backing |

Online member classes come exclusively from `grug_classes.get_class`. Offline
rows retain only their name and offline status, with no fabricated HP or class.
The existing half-second HUD refresh compares the quantized width and texture
with their prior values, so unchanged health, class and preference produce no
HUD packets. Class changes also use the established party change callback for
an immediate refresh.

`tools/r17_party/kat.lua` loads the production preference, party-view, Group
page, HUD and layout paths. Through the real `ui.lua` receive-fields callback it
checks dropdown indices `2` and `1`, rejects an invalid field without mutation,
and verifies the generated selected index and top-right geometry. It also checks
the default, reconnect persistence, all four exact colors, canonical online
class projection, offline state and zero unchanged HUD writes. Root owns the
final compact PUC 5.1/LuaJIT parity pair on integrated bytes.
