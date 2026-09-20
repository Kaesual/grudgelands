# Final six-capital engine evidence review

## Scope

- Frozen integration candidate: `2fcda6086cdf7c78c50e0037935b39933dd67e6b`.
- Evidence root: `/tmp/grudgelands-r10-final-engines/capitals-v2`.
- Reviewed all six runner summaries, server/error counters, probe output, service and precinct TSVs, overlay digests/deltas, candidate binding and harness hashes.
- Artifact-only review: no Lua interpreter or engine process was started.

The candidate contains reviewed display correction `561a9c2b23954947c7dabf09ec409739786610af` as its second parent. The production `start_npcs.lua` and regression `start_npcs_kat.lua` bytes are unchanged between that parent and `2fcda608`; therefore these engine outputs exercise the reviewed fix. Every capital records the same five final harness hashes.

## Runtime results that pass

All six real server processes report engine exit 0, error count 0, mod-error count 0 and exactly one `event=complete`:

| Capital | Complete | Services | Precinct | Alchemy | Display placements |
|---|---:|---|---|---|---:|
| Dur Brannoc | 120/120 | PASS | PASS | brewed 10 | 7 |
| Gor Drazhak | 94/94 | PASS | PASS | brewed 10 | 7 |
| Highcourt | 105/105 | PASS | PASS | brewed 10 | 7 |
| Kezamba | 78/78 | PASS | PASS | brewed 10 | 7 |
| Lethariel | 80/80 | PASS | PASS | brewed 10 | 7 |
| Nhal Veyr | 91/91 | PASS | PASS | brewed 10 | 7 |

Each service witness reports the exact 23-service roster across eight owning plots: 7 public stations, 8 profession trainers, 1 Riding Trainer, 4 mount displays and 3 gear displays. Each real log contains all seven `capital_display placed at socket` events, so the former all-capital startup crash is absent across all six layouts.

Each alchemy witness learns the profession, brews and extracts 10 `grug_alchemy:potion_healing`, reports profession level 2 and exposes book tiers 1–6. Each precinct witness reports four authored gates and `status=PASS`. Every final emitted region in each `event=complete` line has `ignored=0`, `unheld=0` and `emerge_trouble=0`; some regions needed a bounded retry after an initially unloaded read, but their accepted final dumps contain no ignored cells.

## Unresolved geometry gate

**The six-capital runner does not pass overall.** `results.json` correctly records exit 1 for all six wrapper jobs. Their engine subprocesses and semantic witnesses completed, but old-overlay digest comparison remains unresolved:

- all six avenue labels differ from the committed historical digest;
- Dur Brannoc, Gor Drazhak, Highcourt and Nhal Veyr also differ for rampart and gate;
- those same four capitals' corner digests match exactly;
- Kezamba and Lethariel publish no rampart, corner or gate overlay labels.

That is 14 `changed-review-required` labels and four exact corner matches. The mismatch is not waived here and is not normalized into new expected values. Its cause and whether each delta is an accepted consequence of reviewed world/CAP changes remain owned by the separate geometry attribution review.

## Verdict

**CLEAN for actual server completion, error-free service placement, display correction, precinct semantics and Alchemy interaction across all six capitals. OVERALL ENGINE GATE REMAINS OPEN for the 14 old-overlay digest deltas.**

This report must not be cited as an overall runner PASS until the independent old/new geometry attribution closes every changed label against intended source changes. No new runtime defect was found in the passing portions; the unresolved digest gate is retained exactly as emitted.
