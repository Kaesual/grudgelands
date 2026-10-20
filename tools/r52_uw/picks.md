# 0.52.1 UW: underwater bed candidates

Written by `cut.py`. Files in `out/`; the window is in seconds of the source preview (excerpt = loop +
2 s crossfade). Scan columns (dB, lower is calmer): burst = loudest moment over the window median,
seam = loudest moment in the crossfade zones over the median, jump = level difference of the loop's ends,
spread = p90 - p10 of the level, high = loudest moment above 2 kHz over its median. The winner ships as
`grug_ambience_underwater.ogg`. The coordinator fills the verdict column from the page (the user, 2026-10-20: two picks ship as one pool; rows without a verdict were not rated).

| File | Freesound id | Window | Loop | Measured | Scan | Verdict |
|---|---|---|---|---|---|---|
| uw_1_fission9.ogg | 504641 (Fission9) | 14.4-46.4 s of 46.86 s | 30 s | -20.1 LUFS, peak -1.0 dBFS (limited) | burst 5.0, seam 1.4, jump 0.9, spread 4.4, high 11.9 dB | |
| uw_2_dcsfx.ogg | 366159 (DCSFX) | 62.9-94.9 s of 240 s | 30 s | -20.1 LUFS, peak -1.1 dBFS (limited) | burst 4.3, seam 1.2, jump 0.1, spread 4.0, high 6.4 dB || pick (shipped as grug_ambience_underwater_dcsfx.ogg) |
| uw_3_kinoton.ogg | 393819 (Kinoton) | 237.9-269.9 s of 311.18 s | 30 s | -20.1 LUFS, peak -4.9 dBFS | burst 2.6, seam 2.2, jump 0.0, spread 3.2, high 7.9 dB | |
| uw_4_verberne.ogg | 482167 (Tim_Verberne) | 14.9-46.9 s of 120 s | 30 s | -20.1 LUFS, peak -4.6 dBFS | burst 2.3, seam 0.0, jump 0.1, spread 3.2, high 11.7 dB || pick (shipped as grug_ambience_underwater_verberne.ogg) |
| uw_5_merrick.ogg | 567347 (Merrick079) | 8.4-40.4 s of 44 s | 30 s | -20.1 LUFS, peak -4.9 dBFS | burst 4.5, seam 0.1, jump 0.3, spread 5.2, high 5.9 dB | |
| uw_6_jhumbucker.ogg | 193822 (jhumbucker) | 9.4-41.4 s of 109.57 s | 30 s | -20.1 LUFS, peak -1.2 dBFS (limited) | burst 2.6, seam 0.0, jump 0.4, spread 2.9, high 2.0 dB | |
| uw_7_cubicapocalypse.ogg | 195509 (cubicApocalypse) | 0.4-24.9 s of 25.2 s | 22.5 s | -20.1 LUFS, peak -3.8 dBFS | burst 2.1, seam 0.8, jump 2.1, spread 2.6, high 2.1 dB | |
| uw_8_osiruswaltz.ogg | 530167 (Osiruswaltz) | 0.4-15.8 s of 16.11 s | 13.4 s | -20.0 LUFS, peak -5.6 dBFS | burst 1.0, seam 1.0, jump 1.0, spread 1.6, high 1.8 dB || drop |
