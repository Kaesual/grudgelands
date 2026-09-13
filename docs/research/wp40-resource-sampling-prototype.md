# Resource-root sampling prototype — 2026-09-13

**Status: historical measured prototype; adopted by the user on 2026-09-13.**
This report records the reviewed `wp40-resource-sampling-prototype` experiment
based on `a87b58c`. Its evidence remains unchanged. Subsequent production
integration and current acceptance checks are recorded in
[the adoption report](wp40-resource-sampling-integration.md).

## Result

The proposed sampler removes the dominant resource-root ranking work. Three
fresh-world runs per variant used the same local Flatpak Luanti 5.17.0 release,
LuaJIT runtime, ten owners, seed `0`, timing harness and idle scheduling. The
figures below are callback medians; aggregate rows are medians of each complete
run's sum, not sums of independently selected medians.

| Population | Current generator | Prototype | Time reduction |
|---|---:|---:|---:|
| All ten tested owners | 13.923 s | 6.447 s | 53.7% |
| Nine surface owners | 7.427 s | 5.692 s | 23.4% |
| Whitebridge owner | 2.114 s | 0.873 s | 58.7% |
| Deep cross-border owner | 6.810 s | 0.747 s | 89.0% |

The deep owner's writer median falls from 6.290 to 0.347 seconds. The prior
coarse diagnostic attributed almost all its writer time to P8, including
5,217,700 root hashes. Sampling needs one root-seed hash for each positive-budget
resource/cell/segment, rather than a hash for every eligible voxel, and does not
build a root heap. Frontier hashes and the eligible-host scan remain.

Simple surface owners do not all improve: the first pine owner is 0.523 versus
0.537 seconds, within the observed timing spread. This is a local workstation
comparison, not a 100-player load test or a universal per-chunk speed promise.
No Rehearsal VM or GUI was used. Separate audit runs execute in parallel and
are excluded from these timing medians.

## Algorithm and trade-off

The writer enumerates the same eligible host coordinates in the same order,
computes the same density budget and planned vein targets, then initializes a
cell-local Park-Miller stream from one SHA-256 digest. A new domain separates
that digest from every existing decision. Its canonical fields bind the full
world-seed string, resource key, cell x/y/z, host, tier and deep band.

Each requested root draws an index from the remaining active prefix of the
coordinate scratch array, swaps that record with the tail and shrinks the
prefix. This lazy Fisher-Yates selection never selects the same candidate
twice. Previously claimed roots consume a draw and the search continues.
Resource precedence, live claims, regional exclusions, budget arithmetic,
maximum target vein size and frontier growth rules are unchanged. Both the
full VM writer and its horizontal census use the sampler. Zero-budget groups
need no root-seed hash.

Specific ore positions and the shapes resulting from growth at those positions
change. The same seed remains reproducible. Planned quantities are unchanged;
actual quantities can differ slightly when a vein cannot grow its full target.
The sampler is not a cryptographic or perfectly uniform random permutation:
its 31-bit state derives from a 32-bit digest prefix modulo 2,147,483,646, giving
the first four states three preimages and other states two. Per-draw rejection
avoids an additional modulo-reduction bias. The multiplication is below 2^46,
well within the exact-double 2^53 bound on both supported interpreters.

The prototype includes the earlier resource eligibility cache and early exits.
The cache holds at most 512,000 numeric entries per runtime writer and resets
per transaction; owners without predecessor runs bypass it. No old-world
reader, compatibility switch, migration or persistent cache is introduced.
The optional bounded string-prefix experiment remains outside this prototype.

## Distribution and non-ore content

A separate real-engine audit compares **50 owners across three seeds**, all
15 resource types, all six material tiers and all three deep-density bands.
It covers 30 depth owners, ten additional human/dwarf owners to include the
otherwise missing regional resources, and the ten original surface owners.
The seeds are `0`, `4074524248646631899` and `4655649881628627392`.

For all **54,131 resource/cell/segment rows**, the eligible count, budget and
planned vein count are exactly identical. The observed totals are:

| Metric | Current generator | Prototype |
|---|---:|---:|
| Target ore blocks | 592,523 | 592,523 |
| Planned / accepted veins | 100,417 / 100,417 | 100,417 / 100,417 |
| Placed ore blocks | 592,509 | 592,517 |
| Unfilled target blocks | 14 | 6 |
| Foreign-root collision attempts | 1,408 | 1,386 |

The eight-block difference is +5 copper and +3 tin, about 0.00135% of placed
ore. Every other resource's total is identical. This is measured evidence for
this corpus, not a guarantee of identical supply on all future seeds.

The actual VM ore counts match the writer's placed counts. Replacing only ore
nodes by their tier's host yields identical full content digests for all 50
owners; param2 and light also match. Thus the audited non-ore content, including
terrain and vegetation in the surface sample, is unchanged. Each cold/disk
pair checks all 5,120,000 content/param2/light values, and disk-only reloads have
zero generation callbacks. Each variant's three ordinary timing repeats has
identical full output; baseline and sampler outputs intentionally differ.

## Memory and validation

Sampled actual engine high-water RSS for the baseline cold runs was about
1.36–1.41 GiB; the sampled prototype cold run was about 1.045 GiB. Disk-only
processes were about 0.89–0.91 GiB baseline and 0.868 GiB prototype. These include
both Lua environments, game state, VoxelManip and diagnostic buffers, and are
not isolated allocator measurements. Avoiding millions of short-lived hash
strings is consistent with the lower observed peak; causality and a precise
memory saving are not established by these samples.

The sampler KAT checks literal known answers, exact framing, invalid inputs,
closure isolation, a forced rejection and unique exhaustion of 4,096 roots.
The actual writer fixture compares ordinary/runtime VM content, param2, light,
operation traces and exact hash framing; it checks inactive resources,
zero-budget/no-seed behavior, claims, budget conservation, cache reuse and the
no-predecessor bypass. A compact actual census call checks the separate changed
census branch. The 16,384-cell/64-bin statistical smoke and expanded writer
fixture run only under LuaJIT. Parser, SETGLOBAL and five static sweeps pass.

Final compact parity is 27 byte-identical PUC/LuaJIT lines, SHA-256
`9a71c1df7056d6d12d13be9d6d61b7a7d21136146f91f918722c6c35fd7ac42d`.
The [review receipt](wp40-resource-sampling-evidence/review.md) records GPT-6
coordinator implementation, configured GPT-5.6 Sol fixtures and independent
review, zero Critical/High/Medium findings, one initial Low proof-comment fix
and one final Low receipt/calibration fix (two fix rounds; elapsed unknown).
Technical evidence is in the [archive](wp40-resource-sampling-evidence/README.md). This prototype check does
not replace the complete integration gate or the user's fallback-engine gate.

## Recommendation and adoption boundary

The prototype recommended adoption because the measured gain was substantial,
while the observed supply difference was tiny and planned supply unchanged.
The user approved adoption on 2026-09-13. Current specification, integration
checks and merge evidence belong to [the adoption report](wp40-resource-sampling-integration.md).
The archived evidence README and review describe their original prototype-time
status; their references to a pending decision are historical. Historical exact-
position and supply artifacts retain their algorithm identity and are not
current proof for the sampler. The 50-owner audit is not a new whole-world
32-seed supply/access certificate.

After adoption and sync, the user runtime check is to explore fresh surface and
deep terrain, inspect several ore veins, and revisit generated chunks. Confirm
normal terrain/vegetation, mining behavior and fast exploration without errors.
No automatic world cleanup or migration is part of either step.
