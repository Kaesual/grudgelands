#!/usr/bin/env bash
# 0.52.1 lane UW: serial Freesound CC0 searches for the underwater bed, one locked
# call per query (r34/fs_run.sh). Queries in sound-r52u/queries.tsv (key<TAB>query);
# results land in sound-r52u/fs/<key>.json (skipped when already there).
O=/home/jan/projects/grudgelands-orchestration
B=$O/sound-r52u
S=$O/r34/listen/scripts/fs_search.py
while IFS=$'\t' read -r key q; do
  [[ -s $B/fs/$key.json ]] && continue
  "$O/r34/fs_run.sh" "r52u-$key" python3 -I "$S" "$q" "${N:-10}" >"$B/fs/$key.json" 2>"$B/fs/$key.err"
done <"$B/queries.tsv"
echo DONE
