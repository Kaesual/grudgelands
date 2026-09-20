# R10 equipment final evidence

The final micro-KAT runner was executed against source commit `77bf1eb1` after
the exact recipe-oracle correction. The subsequent candidate changes only add
this evidence and clarify design prose; they do not change Lua under test.

Commands (from the repository root):

```text
/usr/bin/luajit tools/r10_equip/evidence/final_micro.lua "$PWD" > final-luajit.txt
tools/bin/lua51 tools/r10_equip/evidence/final_micro.lua "$PWD" > final-puc51.txt
cmp final-luajit.txt final-puc51.txt
```

Both 194-line outputs have SHA-256
`50756e38b046e128518ef3fd9523efd575439b5feeaed893fbe451eecc79e2e1`.
The runner has SHA-256
`f6f87e6e5e8b13f755e5aaf6aad8358f67a8c9e3456905c7116a537ad9697471`.
The PUC 5.1 executable has SHA-256
`a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f`;
the LuaJIT executable has SHA-256
`4fd1f5075a6cb15c933f5abaf7ad4b203c8926ab27261c334b41c9bc5e40a1a6`.

`framework_kat.lua` in the runner exercises callback replacement threading,
late terminal-gate restoration and refused first craft. `quality_kat.lua`
exercises copy-before-mutation and preservation of arbitrary source metadata;
its `station_ops preserve stack` receipt is included in both logs.

An independent source review of the candidate remains outstanding. These logs
are author evidence, not that review.
