# R10 GAME final parity evidence

These are the authoritative replacement outputs for source freeze
`b35d06ec` (the full commit is recorded by Git). They supersede every earlier
GAME pair in `/tmp` and the narrative-only evidence reference in the preceding
candidate.

From the repository root, with no concurrent Lua runtime in this lane:

```text
chrt --idle 0 ionice -c3 tools/bin/lua51 tools/r10_gameplay/final_micro.lua "$PWD" > tools/r10_gameplay/evidence/final-puc51.txt
chrt --idle 0 ionice -c3 /usr/bin/luajit tools/r10_gameplay/final_micro.lua "$PWD" > tools/r10_gameplay/evidence/final-luajit.txt
cmp tools/r10_gameplay/evidence/final-puc51.txt tools/r10_gameplay/evidence/final-luajit.txt
```

The two processes ran concurrently against immutable source bytes. Both outputs
are byte-identical and have SHA-256
`cf2d5389dc632667b8ec9d66752ac3f9acc072d77e48f050f0aa974aaecbf327`.
The runner SHA-256 is
`fce0e01796b6f0bf120072ce2c2f5caa19a9f7c5f90d65c422ef5d55d8e4adc7`;
the final cliff fixture SHA-256 is
`51e7a3ed74d793ed8ec791029df7386ad5884ac3b65bf1ef57a57867a6a9985a`.
The PUC 5.1 executable SHA-256 is
`a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f`;
the LuaJIT executable SHA-256 is
`4fd1f5075a6cb15c933f5abaf7ad4b203c8926ab27261c334b41c9bc5e40a1a6`.
