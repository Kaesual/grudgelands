Round 49 P8 follow-up (per-chunk cube decisions in the fill ores).

mgprof-after: one stage boot of r49-p8 (tools/mgprof/run.sh stages, seed 12345).
P8 (s.p8_resources) summed over all 89 callbacks of a boot (preparation and corpus),
and the median of the fill chunks (P8 > 5 ms, 40-41 per boot):
  main e43c886b, before HASH (tools/r49_hash/evidence/mgprof-before)      633 ms  median 14.6
  HASH, first mix (tools/r49_hash/evidence/mgprof-after)                  566 ms  median 14.4
  HASH, cube-round mix, main 62123545 (tools/r49_hash/evidence/mgprof-after-cube)  796 ms  median 18.5
  r49-p8 (mgprof-after)                                                   541 ms  median 12.6

Fleet digest (tools/r49_jit/fleet_digest.sh, quick seeds): main 62123545 and r49-p8 give
identical files (502 chunks, 100 seeds OK): fleet-digest-quick.txt.
