# Profession station media

Round 11 imports seven unchanged renamed textures from pinned VoxeLibre
`c2dbc520ff4e1637072d33b06c3a2404e0f08df7`,
<https://github.com/VoxeLibre/VoxeLibre>. XSSheep / Pixel Perfection and
VoxeLibre contributors; **CC BY-SA 4.0**, per upstream `LEGAL.md` texture section.

| Local name | Upstream textures/ file | Treatment |
| --- | --- | --- |
| grug_jobs_anvil_top.png | mcl_anvils_anvil_top_damaged_0.png | unchanged copy; native facedir/top rotation |
| grug_jobs_anvil_base.png | mcl_anvils_anvil_base.png | unchanged copy |
| grug_jobs_anvil_side.png | mcl_anvils_anvil_side.png | unchanged copy |
| grug_jobs_loom_top.png | loom_top.png | unchanged copy |
| grug_jobs_loom_bottom.png | loom_bottom.png | unchanged copy |
| grug_jobs_loom_side.png | loom_side.png | unchanged copy |
| grug_jobs_loom_front.png | loom_front.png | unchanged copy |

The goldsmith's top surface uses a native muted-gold texture modifier, retaining
the dark metal base and side. Four anvil box coordinates follow the upstream
node geometry in `mods/ITEMS/mcl_anvils/init.lua:383-391`; no upstream falling,
repair, enchantment, inventory or interaction code is imported. The loom's six
face ordering follows `mods/ITEMS/mcl_loom/init.lua:8-12`.
