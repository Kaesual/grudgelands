#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/time -a -o "${WP40_PROFILE_OUTPUT:?}/rss.tsv" -f 'wall_s=%e max_rss_kib=%M' /tmp/grug-throughput-flatpak.sh "$@"
