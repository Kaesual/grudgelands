#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

user_path="${LUANTI_USER_PATH:?isolated profiler user path required}"
case "$user_path" in
	/tmp/grudgelands-wp40-profile-run.*/user) ;;
	*) echo 'refusing non-profiler user path' >&2; exit 2 ;;
esac

profile_root="$(dirname "$user_path")"
[[ "$profile_root" == "$(realpath -e "$profile_root")" ]] || exit 2
[[ "$user_path" == "$profile_root/user" ]] || exit 2

result_path="${WP40_PROFILE_OUTPUT:?explicit profiler result path required}"
[[ "$result_path" == "$(realpath -e "$result_path")" ]] || exit 2
result_root="$(dirname "$result_path")"
[[ "$result_root" == /tmp/grudgelands-r10-final-engines/six-starts ]] || exit 2
case "$(basename "$result_path")" in
	forward|reverse) ;;
	*) echo 'refusing unexpected six-start result path' >&2; exit 2 ;;
esac

xdg_root="$profile_root/xdg"
mkdir -p "$xdg_root/cache" "$xdg_root/data" "$xdg_root/config" \
	"$xdg_root/runtime/.flatpak"
chmod 700 "$xdg_root/runtime"

export XDG_CACHE_HOME="$xdg_root/cache"
export XDG_DATA_HOME="$xdg_root/data"
export XDG_CONFIG_HOME="$xdg_root/config"
export XDG_RUNTIME_DIR="$xdg_root/runtime"

exec flatpak run --command=luanti \
	--filesystem="$profile_root" --filesystem="$result_path" \
	--env=LUANTI_USER_PATH="$user_path" \
	--env=XDG_CACHE_HOME="$XDG_CACHE_HOME" \
	--env=XDG_DATA_HOME="$XDG_DATA_HOME" \
	--env=XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
	--env=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" --env=LC_ALL=C \
	org.luanti.luanti "$@"
