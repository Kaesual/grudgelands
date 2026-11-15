#!/bin/sh
# Builds `gen`, which prints the engine's own SRP verifier (hex) for a name, a
# password and a salt (hex), from the vendored Luanti sources in
# reference_projects/luanti: util/srp.cpp with the bundled mini-gmp and sha256.
# The binary goes to the directory given (default: a temporary one) and is never
# committed. Usage: tools/web_accounts/engine_vectors/build.sh [OUT_DIR]
set -eu
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
L="$ROOT/reference_projects/luanti"
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT/stub"
printf '#pragma once\n#define USE_SYSTEM_GMP 0\n' > "$OUT/stub/config.h"
printf '#pragma once\n#include <cstddef>\nnamespace porting { bool secure_rand_fill_buf(void *buf, size_t len); }\n' > "$OUT/stub/porting.h"
: > "$OUT/stub/cmake_config.h"
cp "$L/src/util/srp.h" "$L/src/util/srp.cpp" "$OUT/stub/"
cd "$OUT"
g++ -std=c++17 -O1 -w -Istub -I"$L/lib/gmp" -I"$L/lib/sha256" -c "$ROOT/tools/web_accounts/engine_vectors/gen.cpp" stub/srp.cpp
gcc -O1 -w -Istub -I"$L/lib/gmp" -I"$L/lib/sha256" -c "$L/lib/gmp/mini-gmp.c" "$L/lib/sha256/sha256.c"
g++ gen.o srp.o mini-gmp.o sha256.o -o gen
echo "$OUT/gen"
