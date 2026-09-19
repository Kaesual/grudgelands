#!/usr/bin/env python3
"""Compare full-digest fresh-start runs, separating explicit corpus and other owners."""
import argparse
import csv
import re
import statistics
import sys
from pathlib import Path


def fields(line):
    return dict(re.findall(r"(\w+)=([^ ]+)", line))


def read_run(root):
    summary = dict(line.split("\t", 1) for line in (root / "summary.tsv").read_text().splitlines())
    environment = dict(line.split("\t", 1) for line in (root / "environment.tsv").read_text().splitlines())
    # Paths differ between immutable checkouts; ordered file hashes must not.
    harness = tuple(line.split()[0] for line in (root / "harness.sha256").read_text().splitlines())
    identity = (summary["full_digest"], summary["full_vocabulary_digest"],
                summary["full_voxels"], summary["sample_digest"], harness,
                (root / "engine-version.txt").read_text(), environment["seed"],
                environment["settlement_stages"])
    assert re.fullmatch(r"[0-9a-f]{64}", identity[0]), "full generated-owner digest absent"
    assert summary["disk_mapgen_callbacks"] == "0"
    assert int(summary["disk_loaded_blocks"]) > 0
    assert int(summary["full_owners"]) == int(summary["cold_mapgen_callbacks"])
    assert int(summary["full_voxels"]) == int(summary["full_owners"]) * 512000
    callbacks, corpus, complete = {}, set(), []
    for line in (root / "cold/profile-events.log").read_text().splitlines():
        values = fields(line)
        if "GRUG_WP40_PROFILE_CALLBACK " in line:
            owner = values["minp"]
            assert owner not in callbacks, f"duplicate owner: {owner}"
            callbacks[owner] = values
        elif values.get("event") == "emerge":
            assert values["mapchunk"] not in corpus, "duplicate corpus owner"
            corpus.add(values["mapchunk"])
        elif values.get("event") == "complete":
            complete.append(values)
    assert len(complete) == 1
    assert len(corpus) == 10 and corpus <= callbacks.keys(), "corpus callback missing"
    assert len(callbacks) == int(summary["cold_mapgen_callbacks"])
    assert len(callbacks) == int(complete[0]["callbacks"])
    return identity, callbacks, corpus, int(complete[0]["measured_elapsed_us"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", nargs="+", help="LABEL=RESULT_DIRECTORY; repeat in pair order")
    parser.add_argument("--pair-labels", nargs=2, metavar=("BEFORE", "AFTER"),
                        help="report paired AFTER/BEFORE ratios in occurrence order")
    args = parser.parse_args()
    groups, expected, owner_set, corpus_set = {}, None, None, None
    for item in args.results:
        label, directory = item.split("=", 1)
        identity, callbacks, corpus, elapsed = read_run(Path(directory))
        if expected is None:
            expected, owner_set, corpus_set = identity, set(callbacks), corpus
        assert identity == expected, f"generated-owner output or measurement inputs differ: {directory}"
        assert set(callbacks) == owner_set and corpus == corpus_set, "callback owner sets differ"
        groups.setdefault(label, []).append((callbacks, elapsed))
    writer = csv.writer(sys.stdout, delimiter="\t", lineterminator="\n")
    writer.writerow(("kind", "variant", "population", "metric", "runs", "median", "min", "max"))
    samples = {}
    for label, runs in groups.items():
        for population, owners in (("corpus", corpus_set),
                                   ("startup_other", owner_set - corpus_set), ("all", owner_set)):
            writer.writerow(("owners", label, population, "count", len(runs), len(owners), "-", "-"))
            for key in ("plan_us", "writer_us", "total_us"):
                values = [sum(int(callbacks[owner][key]) for owner in owners) for callbacks, _ in runs]
                samples[label, population, key] = values
                writer.writerow(("total_us", label, population, key, len(values),
                                 statistics.median(values), min(values), max(values)))
        values = [elapsed for _, elapsed in runs]
        samples[label, "fresh_start", "elapsed_us"] = values
        writer.writerow(("total_us", label, "fresh_start", "elapsed_us", len(values),
                         statistics.median(values), min(values), max(values)))
    if args.pair_labels:
        before, after = args.pair_labels
        assert before in groups and after in groups
        assert len(groups[before]) == len(groups[after]), "unpaired runs"
        for (label, population, metric), denominators in samples.items():
            if label != before:
                continue
            numerators = samples[after, population, metric]
            if not all(denominators):
                continue  # Empty startup population is valid for an isolated corpus.
            ratios = [a / b for a, b in zip(numerators, denominators)]
            for index, ratio in enumerate(ratios, 1):
                writer.writerow(("paired_ratio", f"{after}/{before}:{index}", population,
                                 metric, 1, ratio, ratio, ratio))
            writer.writerow(("paired_ratio_summary", f"{after}/{before}", population,
                             metric, len(ratios), statistics.median(ratios), min(ratios), max(ratios)))


if __name__ == "__main__":
    main()
