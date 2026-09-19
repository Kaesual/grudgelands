#!/usr/bin/env python3
"""Small log fixtures for order-independent startup/corpus comparisons."""
import importlib.util
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/wp40/profile/compare.py"
spec = importlib.util.spec_from_file_location("compare", SCRIPT)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)
with tempfile.TemporaryDirectory() as scratch:
    roots = [pathlib.Path(scratch) / name for name in ("a", "b")]
    for index, root in enumerate(roots):
        (root / "cold").mkdir(parents=True)
        summary = dict(full_digest="a" * 64, full_vocabulary_digest="b" * 64,
                       sample_digest="c" * 64, full_voxels=str(11 * 512000),
                       full_owners="11", cold_mapgen_callbacks="11",
                       disk_mapgen_callbacks="0", disk_loaded_blocks="1250")
        (root / "summary.tsv").write_text("".join(f"{k}\t{v}\n" for k, v in summary.items()))
        (root / "harness.sha256").write_text("d" * 64 + f"  /different/{index}/probe.lua\n")
        (root / "engine-version.txt").write_text("Luanti 5.17.0\n")
        (root / "environment.tsv").write_text("seed\t0\nsettlement_stages\t0\n")
        lines = [f"GRUG_WP40_PROFILE_CALLBACK minp={x},0,0 plan_us=10 writer_us=20 total_us=30"
                 for x in range(11)]
        if index:
            lines.reverse()
        lines += [f"GRUG_WP40_PROFILE_PROBE event=emerge mapchunk={x},0,0" for x in range(10)]
        lines += ["GRUG_WP40_PROFILE_PROBE event=complete callbacks=11 measured_elapsed_us=500"]
        (root / "cold/profile-events.log").write_text("\n".join(lines))
        assert len(compare.read_run(root)[1]) == 11
    result = subprocess.run([sys.executable, str(SCRIPT), "--pair-labels", "before", "after",
                             f"before={roots[0]}", f"after={roots[1]}"],
                            capture_output=True, text=True, check=True)
    assert "owners\tbefore\tcorpus\tcount\t1\t10" in result.stdout
    assert "owners\tbefore\tstartup_other\tcount\t1\t1" in result.stdout
    assert "paired_ratio_summary\tafter/before\tall\ttotal_us\t1\t1.0" in result.stdout
    path = roots[1] / "summary.tsv"
    path.write_text(path.read_text().replace("a" * 64, "e" * 64))
    assert subprocess.run([sys.executable, str(SCRIPT), f"a={roots[0]}", f"b={roots[1]}"],
                          capture_output=True).returncode != 0
print("profile_compare_test PASS (startup partition, callback order, paths, digest mismatch)")
