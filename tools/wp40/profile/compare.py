#!/usr/bin/env python3
"""Validate frozen engine A/B evidence and report callback medians (microseconds)."""
import argparse
import csv
import re
import statistics
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("results", nargs="+", help="LABEL=RESULT_DIRECTORY (repeat labels for repeats)")
args = parser.parse_args()
groups = {}
expected = None
for item in args.results:
    label, directory = item.split("=", 1)
    root = Path(directory)
    summary = dict(line.split("\t", 1) for line in (root / "summary.tsv").read_text().splitlines())
    identity = (summary["full_digest"], summary["full_vocabulary_digest"],
                summary["full_voxels"], (root / "harness.sha256").read_text(),
                (root / "engine-version.txt").read_text())
    assert re.fullmatch(r"[0-9a-f]{64}", identity[0]), "full owner digest absent"
    assert summary["cold_mapgen_callbacks"] == "10"
    assert summary["disk_mapgen_callbacks"] == "0"
    assert summary["disk_loaded_blocks"] == "1250"
    assert summary["full_voxels"] == "5120000"
    if expected is None:
        expected = identity
    assert identity == expected, f"output or measurement inputs differ: {root}"
    callbacks = []
    for line in (root / "cold/profile-events.log").read_text().splitlines():
        if "GRUG_WP40_PROFILE_CALLBACK " in line:
            values = dict(re.findall(r"(\w+)=([^ ]+)", line))
            callbacks.append(values)
    assert len(callbacks) == 10
    groups.setdefault(label, []).append(callbacks)

import sys
writer = csv.writer(sys.stdout, delimiter="\t", lineterminator="\n")
writer.writerow(("variant", "owner", "runs", "plan_median_us", "writer_median_us",
                 "callback_median_us", "callback_min_us", "callback_max_us"))
for label, runs in groups.items():
    for index in range(10):
        owners = {run[index]["minp"] for run in runs}
        assert len(owners) == 1
        values = {key: [int(run[index][key]) for run in runs]
                  for key in ("plan_us", "writer_us", "total_us")}
        writer.writerow((label, owners.pop(), len(runs),
                         *(statistics.median(values[key]) for key in values),
                         min(values["total_us"]), max(values["total_us"])))
