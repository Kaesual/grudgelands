#!/usr/bin/env bash
set -euo pipefail

repo="${1:?repository root is required}"
observed_at="$(date --iso-8601=seconds)"
cpu_model="$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')"
logical_cpus="$(getconf _NPROCESSORS_ONLN)"
physical_cores="$(lscpu -p=CORE,SOCKET | awk -F, '!/^#/ {seen[$1 ":" $2]=1} END {print length(seen)}')"
memory_bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
memory_available_bytes="$(awk '/MemAvailable/ {print $2 * 1024}' /proc/meminfo)"
swap_total_bytes="$(awk '/SwapTotal/ {print $2 * 1024}' /proc/meminfo)"
swap_free_bytes="$(awk '/SwapFree/ {print $2 * 1024}' /proc/meminfo)"
governor="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || printf 'unavailable')"
kernel="$(uname -srvm)"
os_release="$(tr '\n' ' ' </etc/os-release)"
loadavg="$(cat /proc/loadavg)"
uptime_text="$(uptime)"
mount_json="$(findmnt -T "$repo" -o FSTYPE,OPTIONS,TARGET -J)"
block_json="$(lsblk -J -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS)"
bios_version="$(cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null || printf 'unavailable')"
bios_date="$(cat /sys/devices/virtual/dmi/id/bios_date 2>/dev/null || printf 'unavailable')"

temperature="unavailable"
if command -v sensors >/dev/null 2>&1; then
	temperature="$(sensors 2>&1 || true)"
fi

jq -n \
	--arg schema "wp40_host_manifest_v1" \
	--arg observed_at "$observed_at" \
	--arg cpu_model "$cpu_model" \
	--argjson physical_cores "$physical_cores" \
	--argjson logical_cpus "$logical_cpus" \
	--argjson memory_bytes "$memory_bytes" \
	--argjson memory_available_bytes "$memory_available_bytes" \
	--argjson swap_total_bytes "$swap_total_bytes" \
	--argjson swap_free_bytes "$swap_free_bytes" \
	--arg governor "$governor" \
	--arg kernel "$kernel" \
	--arg os_release "$os_release" \
	--arg loadavg "$loadavg" \
	--arg uptime "$uptime_text" \
	--argjson mount "$mount_json" \
	--argjson block_devices "$block_json" \
	--arg bios_version "$bios_version" \
	--arg bios_date "$bios_date" \
	--arg temperature "$temperature" \
	'{schema: $schema, observed_at: $observed_at,
	  cpu: {model: $cpu_model, physical_cores: $physical_cores,
	    logical_cpus: $logical_cpus, governor: $governor},
	  memory: {total_bytes: $memory_bytes,
	    available_bytes: $memory_available_bytes,
	    swap_total_bytes: $swap_total_bytes,
	    swap_free_bytes: $swap_free_bytes},
	  software: {kernel: $kernel, os_release: $os_release},
	  firmware: {bios_version: $bios_version, bios_date: $bios_date},
	  storage: {project_mount: $mount, block_devices: $block_devices},
	  load: {loadavg: $loadavg, uptime: $uptime,
	    temperatures: $temperature}}'
