# Round 21 playtest

Use a **fresh world**; existing terrain is deliberately not rewritten. For the
reported geometry, use seed `7354267267733045968`. Mapgen checks below also apply
to ordinary new seeds. No full-world preparation is necessary for this test.

1. **Capital access:** in Kezamba, walk the inner approach near
   `(1800,66,1448)` and the east exit near `(2056,40,1499)`. Inspect an L-shaped
   junction and a few raised/buried-looking shop entrances in Kezamba and Nhal
   Veyr. Steps and doorways should be usable; surrounding terrain should meet
   the plots naturally. A building may open onto natural ground rather than a
   street. Report the position of any inaccessible entrance.
2. **World appearance:** visit a few POIs; their surrounding fitted ground
   should use biome surfaces rather than broad bare-stone pads. Check the
   beach/cliff near `(-1680,24,-2932)`, flatter inland regions and mountain
   transitions. Natural lakes at Frostbarrow and Moonfall have the new shoreline
   and bed variation; other functional water reaches retain their footprints.
   Coral patches should vary in shape. Freshwater plants and occasional passive
   fish add detail; their sparse distribution means they are not guaranteed at
   every shore or immediately after arrival.
3. **Mining:** try a short ordinary T1 mining session with wood/stone tools.
   Coal, copper and tin should feel easier to obtain. Check later-tier supply
   during normal progression; the resource matrix is a density target, not a
   guaranteed number of tunnel blocks per discovery.
4. **Both furnaces:** smelt normal ores (10s each), make charcoal from a log,
   and make an alloy in the dual furnace. Try logs, coal and charcoal as fuel;
   sticks/planks/other items should be rejected. Watch flame and arrow progress,
   seamless refueling, blocked output, reopening and normal save/reload.
   Personal workspaces show their individual flame in the UI; they do not
   change the public world node's light for that player's private job.
5. **Scout:** craft 200 arrows with one Bronze Bar and two diagonal Sticks:
   `--M / -S- / S--`. No feathers or profession required.
6. **Food and targeting:** hold RMB with food for bite sound and the small food
   motion; cancel early, switch items and interact with an NPC to check cleanup.
   Aim at the boar's visible body from different directions. Its targeting area
   is larger; physical movement/collision is unchanged.
7. **Atlas:** POI tooltips should use authored place names rather than
   `R20 Anchor <number>`.

GUI, audiovisual feel, native engine lighting, multiplayer interaction and
long-term economy acceptance belong to this playtest. The bounded offline
checks do not claim to establish them.
