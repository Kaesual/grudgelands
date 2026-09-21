# Round 14 final portable gate

`micro.lua` runs thirteen bounded production-code fixtures in isolated Lua
namespaces. Development uses LuaJIT. Frozen final bytes use one PUC-5.1 process
and the same driver once under LuaJIT, then compare stdout byte for byte.
Do not substitute a full VM/mapgen population or repeat interpreter runs merely
because a later reader opens this directory.

```
python3 tools/r14_final/static.py
chrt --idle 0 ionice -c3 tools/bin/lua51 tools/r14_final/micro.lua .
chrt --idle 0 ionice -c3 luajit tools/r14_final/micro.lua .
```

The static script inventories every changed Lua file since the Round 14 planning
checkpoint, including tools; inspect all SETGLOBAL and sweep hits. It does not
silently treat strings/comments as executable errors or unconditionally declare
the human inspection complete.

`evidence/` contains the accepted stdout pair, empty stderr files, timing/digest,
source hashes, static inventory and the failed selection-fixture diagnostic.
The complete failed-attempt and correction record is in
`docs/research/round14-completion.md`. Native integration is separate under
`tools/r14_integration/`; actual GUI and fallback-engine acceptance remain with
the user.
