# Independent FARM review

## Verdict

**CLEAN — 0 Critical, 0 High, 0 Medium, 0 Low findings.**

- Candidate `806b0c0fd8d1644ff5edaa8219bc91ca183faeea`
- Base `7e2bc1f0`
- Independent native GPT-5.6 Sol review; I did not author FARM.
- Full nine-file diff reviewed. No candidate edits or runtime duplication. Root's integrated final PUC/LuaJIT parity pair remains pending by design.

## Verified behavior

- Production retains exactly the accepted 17 stable families: all 15 rows from the real `grug_cooking.PLANTS` roster plus the existing Potato and Corn gathering items. Names and registrations are derived from the actual roster rather than copied into a second production table.
- Every family has four stages, 200 wet seconds per stage, one harvest item plus one seed at maturity, and the existing one-harvest-to-two-seeds route. Dry soil pauses the crop timer and stores elapsed wet progress; rehydration resumes that exact value. The current-version every-load LBM starts only missing soil timers and leaves running timers unchanged.
- The production fix closes the real cross-boundary mutation: seed placement now checks the supporting soil and crop position independently before `soil_timer`, timer start or crop write. Each denial records the correct protection violation and consumes no seed. Hoe mutation retains its pre-write support-node protection check.
- The fixture loads the actual farming registration and loops through all 17 registered `grug_farming.CROPS`. It meaningfully exercises hoe preparation, radius-three hydration, seed placement/consumption, a 600-second multi-stage callback, mature drops and seed replanting for every family. Separate cases cover VM soil LBM activation, idempotence, stopped-timer reload, 75-second dry pause/resume and both protected touched positions with no soil/crop/timer mutation.
- Gathering authorization is correctly outside this package: the crop contract uses already-owned harvest items as seed inputs, while wild-source placement and authorization remain in `grug_gathering`/MAP-B. Food-grade acquisition is universal; Alchemist authorization continues to apply to its distinct wild healing-herb source rows. The candidate neither bypasses nor changes that path.
- Evidence input hashes exactly match the four frozen files. Canonical LuaJIT output SHA-256 is `373e12ac49917770244d62d7e7ee0c1581fb43543e5375975050f849a39674c1` and reports 17 full loops. The completion record accurately says MAP-B placement and the integrated parity gate are pending.
- Independent review ran plain Lua 5.1 parsing on the two fixture files and changed production file plus `git diff --check`; all passed. The only production global assignment is the established owning `grug_farming` table. Review of the changed text found no forbidden Lua syntax or sweep-pattern issue.

## Calibration

One full frozen-candidate review, zero findings and zero fix rounds. The candidate is ready for integration subject to Root's shared final parity and later MAP-B/engine gates.

## CAP automerge check

Integration commit `4491c996` preserves the only manual `tools/r9_mounts/mounts_kat.lua` combination correctly:

- CAP replaces the removed profession-trainer extension with the real dedicated Riding trainer form and supplies the needed receive-fields/socket-role fixture seams.
- ART's 12 non-compact icon checks remain in the non-compact branch.
- GAME's compact `seen_icons` scope remains separate, so canonical compact runs still report `assets=0` rather than inheriting non-compact icon state.

No source issue found; no interpreter rerun was needed for this merge-only check.
