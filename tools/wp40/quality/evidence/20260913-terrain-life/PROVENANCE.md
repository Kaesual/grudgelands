# Measurement provenance

The original `candidate-files.sha256` binds the measured terrain worktree at
`d7207a4`, not the later combined tree. Verify it against an export of that
commit. Preserve those hashes and the original before/after TSV files.

The baseline was exported from `291faff` into `/tmp/wp40-baseline-compare`.
`baseline.patch` records every difference in its loaded geometry inputs:
1. Limit the cut/fill metric to columns actually owned by the fitting, exactly
   as in the candidate instrumentation; this changes measurement, not geometry.
2. Skip the historical final composed-axis assertion, allowing the measurement
   to finish. No terrain or route calculation is changed by that bypass.
`baseline-fixture.patch` removes only the new, unused-on-baseline solver
injection from the committed fixture. `baseline-files.sha256` binds those
actual baseline input bytes. Unchanged dependencies come from `291faff`.

To reproduce, export `291faff`, apply `baseline.patch`, copy the measured
`terrain_life_fixture.lua` from `d7207a4`, then apply `baseline-fixture.patch`.
For the after variant export `d7207a4`. For either variant create a distinct
empty scratch directory and run:

```sh
chrt --idle 0 ionice -c3 luajit tools/wp40/quality/terrain_life_fixture.lua   "$variant_root" "$decimal_seed_string" "$output_tsv" "$scratch_directory"
```

Seeds are `0` and `4655649881628627392`. The original runs wrote their TSVs
using this fixture directly; separate terminal transcripts were not retained.
`outputs.sha256` binds the preserved TSV results. CPU times are observations,
not reproducibility assertions.

`integration.patch` records the subsequent integrated-file changes from
`d7207a4`: two Gravewood MTS names in `r6_content.required_input_paths`, plus
localizing discarded nearest-segment return values in `height.lua`. The
surface selector body is byte-identical, and localizing those discarded
values only removes accidental global writes; numeric geometry is unchanged.
The measured r6_content hash is
`ad08b975c083b8b6a3842c589bc75a9f7ae589eb5463f5386ac00bc59aa96efd`;
the integrated hash is
`242b4ef04b368755ebede586a66a7449c4acf9b44d64b42f1e60157f114ebd78`.
`integrated-files.sha256` binds these integrated bytes separately. Final
integrated static checks, composed-axis checks and interpreter parity have
separate artifacts; the original timing TSVs are not relabeled as their runs.
