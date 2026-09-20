#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
user_path="${LUANTI_USER_PATH:?isolated user path required}"
case "$user_path" in
  /tmp/grudgelands-wp40-profile-run.*/user) ;;
  *) echo 'refusing non-profiler user path' >&2; exit 2 ;;
esac
result_path="${WP40_PROFILE_OUTPUT:?explicit profiler result path required}"
case "$result_path" in
  /tmp/grudgelands-r9-perf-20260919/measurement/*) ;;
  *) exit 2 ;;
esac
[[ "$result_path" == "$(realpath -e "$result_path")" ]] || exit 2
profile_root="$(dirname "$user_path")"
[[ "$profile_root" == "$(realpath -e "$profile_root")" ]] || exit 2
mkdir -p "$profile_root/xdg/cache" "$profile_root/xdg/data" "$profile_root/xdg/config" "$profile_root/xdg/runtime"
chmod 700 "$profile_root/xdg/runtime"
exec flatpak run --command=luanti --filesystem="$profile_root" --filesystem="$result_path" \
  --env=LUANTI_USER_PATH="$user_path" \
  --env=XDG_CACHE_HOME="$profile_root/xdg/cache" \
  --env=XDG_DATA_HOME="$profile_root/xdg/data" \
  --env=XDG_CONFIG_HOME="$profile_root/xdg/config" \
  --env=XDG_RUNTIME_DIR="$profile_root/xdg/runtime" --env=LC_ALL=C \
  org.luanti.luanti "$@"
