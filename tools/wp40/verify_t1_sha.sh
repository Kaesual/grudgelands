#!/usr/bin/env bash
set -euo pipefail

labels=(
	grudgelands-wp40-seed-01
	grudgelands-wp40-seed-02
	grudgelands-wp40-seed-03
	grudgelands-wp40-seed-04
	grudgelands-wp40-seed-05
	grudgelands-wp40-seed-06
	grudgelands-wp40-seed-07
)
expected=(
	7ff24c89bd170c96998174d1c6cb47fae6d53aa397956633ec017806d8319f07
	64b9a653b4f2b7d8d762f170427314dda639b603382fb88bbc50344f11890af6
	86ab5f801cd4b1b7aec86fd2dbd1969fe540bbe152e7e5a46c433c9b384cfa0c
	6227ead45bd6f519c280727f8606445c2cc04481c6969ceee9ea4807556d6f46
	60fa4f248299865b0e9873dccd1969569ddb826bf015627e210ddcdaf653d7b0
	70abe95007b0c37179d4a08f776121f9035d8eae8941c0308c9f290a2ed8d43b
	ca35a2ab2280852a40bcaf678d998cb29c33a0b376499507d77acaad2bb0c9f8
)

for index in "${!labels[@]}"; do
	actual="$(printf '%s' "${labels[$index]}" | sha256sum | awk '{print $1}')"
	if [[ "$actual" != "${expected[$index]}" ]]; then
		echo "WP40 SHA known answer mismatch: ${labels[$index]}" >&2
		exit 1
	fi
done

echo "WP40 T1 independent SHA-256 known answers passed"
