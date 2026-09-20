# Correction to the final six-capital engine evidence review

Date: 2026-09-20. This note corrects transcription errors in the byte-preserved `final-capital-engine-review.md` archived at integration evidence commit `e4a5ac76`. It does not replace or silently rewrite that historical review.

## Corrections

The authoritative `event=complete` fields in the frozen `capitals-v2` server logs are:

| Capital | Requested/completed | Services | Precinct | Authored gates | Alchemy | Display placements |
|---|---:|---|---|---:|---|---:|
| Dur Brannoc | 120/120 | PASS | PASS | 4 | brewed 10 | 7 |
| Gor Drazhak | **74/74** | PASS | PASS | 4 | brewed 10 | 7 |
| Highcourt | 105/105 | PASS | PASS | 4 | brewed 10 | 7 |
| Kezamba | 78/78 | PASS | PASS | 4 | brewed 10 | 7 |
| Lethariel | **112/112** | PASS | PASS | **3** | brewed 10 | 7 |
| Nhal Veyr | 91/91 | PASS | PASS | 4 | brewed 10 | 7 |

The original report incorrectly transcribed Gor Drazhak as 94/94 and Lethariel as 80/80. It also generalized that every precinct reported four authored gates; Lethariel's actual passing precinct witness reports three. These are report-accuracy defects, not production failures: every requested chunk completed, and each precinct witness passed its capital-specific authored gate roster.

All other numeric claims were re-extracted and confirmed:

- all six engine subprocesses report exit 0, `error-count=0`, `moderror-count=0`, and exactly one completion event;
- each service witness reports eight plots, seven stations, eight profession trainers, one Riding Trainer, four mount displays and three gear displays;
- every server log contains seven display-placement lines;
- every Alchemy witness reports one event, `learned=true`, brewed 10 healing potions, tiers 1–6 and profession level 2;
- all final-region `ignored`, `unheld` and `emerge_trouble` values sum to zero for each capital; and
- the unresolved overlay accounting remains 14 changed labels and four exact matches.

The corrected numbers do not alter the original scoped verdict: the actual service/display/precinct/Alchemy runtime portions are clean, while the overall engine gate remains open until the separate geometry attribution closes the overlay deltas.

## Machine extraction

`/tmp/grudgelands-r10/reviews/final-capital-engine-extraction.tsv` is a deterministic field extraction from each frozen server log, runner log, error counter, service TSV, precinct TSV and overlay-delta TSV. It includes the candidate identity plus SHA-256 hashes for each source server/probe/service/precinct artifact.

- Extraction TSV SHA-256: `481b572cbf6116b8af058bb7f6aeed078a1dbf8e0b54079c5a91d2654a101930`.
- Frozen candidate in every row: `2fcda6086cdf7c78c50e0037935b39933dd67e6b`.
- Evidence root: `/tmp/grudgelands-r10-final-engines/capitals-v2`.
- Extraction method: Python standard-library text parsing only; no Lua interpreter or engine process.
