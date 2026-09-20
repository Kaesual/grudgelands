# Round 12 generic held pose

Generic third-person/world held icons rotate forward around their centered grip.
Explicit `_grug_wield_pose` values win over existing group dispatch, which wins
over the generic fallback. Existing tool, axe and bow transforms are unchanged;
first-person engine wieldmeshes are outside this package.

`luajit -e 'local r=dofile("tools/wp13/wield_transform_kat.lua")("."); io.write(r); assert(not r:find("FAIL",1,true))'`
loads the actual character B3D and geometry, verifies the forward direction,
explicit priority, existing weapon rotations, dwarf scaling and negative controls.
The fixture initially used diagonal endpoints for the generic icon; correcting
it to top/bottom-center endpoints produced PASS without changing the transform.

Evidence: all 326 first-party and changed Lua files parse under plain Lua 5.1;
changed files contain no SETGLOBAL instruction. Five sweep hits are comments,
string patterns/UI text and frozen manifest data, with no forbidden live syntax
or APIs. All 13 reference pins remain unchanged. No PUC runtime was run under
the session override. Independent review and user GUI acceptance remain separate.
