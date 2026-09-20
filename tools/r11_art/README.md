# Round 11 ART evidence

Run the focused LuaJIT checks from the repository root:

```sh
luajit -e 'io.write(dofile("tools/r11_art/media_kat.lua")(".")); io.write(dofile("tools/wp13/gear_catalogue_kat.lua")(".")); io.write(dofile("tools/wp13/wield_transform_kat.lua")("."))'
python3 tools/r11_art/render_sheet.py . /tmp/r11-art-media.png
python3 tools/r11_art/render_bow_pose.py /tmp/r11-art-pose
```

The first fixture checks every imported media binding and then exercises the
real gear registration plus the real group-to-pose and attachment consumers.
The media sheet shows stored source pixels enlarged with nearest-neighbor
sampling; the quiver is shown at its runtime 64px bound. The bow-pose renderer
reads the live transform through LuaJIT and maps every source pixel through the
same attachment matrix as the existing WP13 geometry fixture. Its body is a
schematic side view, so final first/third-person aesthetics remain a GUI gate.

No PUC runtime, broad registration suite or engine world is part of this
package. Plain Lua 5.1 parsing, SETGLOBAL inspection and all five static sweeps
remain mandatory.
