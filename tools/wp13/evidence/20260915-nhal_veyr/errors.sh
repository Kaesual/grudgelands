#!/usr/bin/env bash
# What an engine pass of Nhal Veyr may log, and nothing else.
#
# `run_capital.sh` gates on `errors == 0` and this capital cannot reach that
# until the NPC vocabulary lane registers the two WAVE-2 vendor entities of the
# sockets contract's section 8.4: `herbalist` and `embalmer` are placed as
# sockets, `grug_traders` registers neither, and the contract's own wording is
# that such a kind "is an error line at placement and an empty socket, never a
# load failure".
#
# So the runner's verdict is not the signal for this capital. The signal is
# that there are EXACTLY those two lines and no others, which is what this
# checks. The day the entities land, the expected count drops to zero and this
# script says so rather than quietly passing.
#
#     errors.sh <server.log>...
set -uo pipefail
export LC_ALL=C

EXPECTED='vendor_herbalist|vendor_embalmer'
status=0
for log in "$@"; do
	total="$(grep -c 'ERROR\|ModError' "$log" || true)"
	expected="$(grep -cE "ERROR.*settlement npcs: nhal_veyr.*($EXPECTED)" "$log" || true)"
	other="$(grep 'ERROR\|ModError' "$log" |
		grep -vE "settlement npcs: nhal_veyr.*($EXPECTED)" || true)"
	printf '%s: %s error line(s), %s of them the two unregistered wave-2 vendors\n' \
		"$log" "$total" "$expected"
	if [[ -n "$other" ]]; then
		printf 'UNEXPECTED:\n%s\n' "$other"
		status=1
	fi
	if [[ "$expected" -ne 2 ]]; then
		printf 'the two wave-2 vendor lines are not both present (%s)\n' "$expected"
		status=1
	fi
done
if [[ "$status" -eq 0 ]]; then
	echo "every pass logs exactly the two predicted lines and nothing else"
fi
exit "$status"
