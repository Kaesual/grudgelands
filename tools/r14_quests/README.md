# Round 14 quest fixtures

Development uses LuaJIT:

```sh
luajit tools/r14_quests/core_kat.lua .
luajit tools/r14_quests/participation_kat.lua .
luajit tools/r14_quests/visibility_kat.lua .
```

These are bounded independent fixtures; none modifies a game world. The
participation fixture loads the real mobs main module while omitting its content
roster. Root's integrated final micro fixture owns the final PUC/LuaJIT pair;
do not run an intermediate PUC suite. Native boot and user runtime remain
separate gates. See `docs/research/round14-quests-work.md` for APIs and coverage.
