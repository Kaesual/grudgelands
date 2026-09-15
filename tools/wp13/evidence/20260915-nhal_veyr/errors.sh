#!/usr/bin/env bash
# What an engine pass of Nhal Veyr may log: NOTHING.
#
#     errors.sh <server.log>...
#
# This file used to allow two: `herbalist` and `embalmer` are WAVE-2 vendor
# kinds and `grug_traders` had not registered their entities, which the sockets
# contract's section 8.4 says is "an error line at placement and an empty
# socket, never a load failure". Lane N landed those entities on main at
# `c8050057` and this package was rebased onto it, so the allowance is gone and
# the expectation is zero.
#
# It stays as a script rather than going back to `run_capital.sh`'s own
# `errors == 0` gate because it says WHICH lines a log carries when it carries
# any, which is what a reviewer needs and an exit code is not.
set -uo pipefail
export LC_ALL=C

status=0
for log in "$@"; do
	total="$(grep -c 'ERROR\|ModError' "$log" || true)"
	printf '%s: %s error line(s)\n' "$log" "$total"
	if [[ "$total" -ne 0 ]]; then
		grep 'ERROR\|ModError' "$log"
		status=1
	fi
done
if [[ "$status" -eq 0 ]]; then
	echo "every pass logs no ERROR and no ModError line"
fi
exit "$status"
