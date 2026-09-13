BEGIN {
	metric_text = "plan_us writer_us total_us columns candidate_cells candidates r5_runs " \
		"vm_get_emerged_area_us vm_get_data_us vm_get_param2_data_us " \
		"vm_get_light_data_us vm_set_data_us vm_set_param2_data_us " \
		"vm_set_lighting_us vm_calc_lighting_us vm_set_light_data_us " \
		"vm_update_liquids_us"
	metric_count = split(metric_text, metric)
	for (metric_index = 1; metric_index <= metric_count; metric_index++)
		wanted[metric[metric_index]] = 1
	print "kind\tname\tcount\ttotal\tmin\tmax\tmean"
}
/GRUG_WP40_PROFILE_CALLBACK/ {
	records++
	result = ""
	for (field = 1; field <= NF; field++) {
		equals = index($field, "=")
		if (equals > 1) {
			name = substr($field, 1, equals - 1)
			value = substr($field, equals + 1)
			if (wanted[name] && value ~ /^-?[0-9]+$/) {
				numeric = value + 0
				seen[name]++
				total[name] += numeric
				if (seen[name] == 1 || numeric < minimum[name]) minimum[name] = numeric
				if (seen[name] == 1 || numeric > maximum[name]) maximum[name] = numeric
			} else if (name == "result") {
				result = value
			}
		}
	}
	if (result != "") results[result]++
}
END {
	for (metric_index = 1; metric_index <= metric_count; metric_index++) {
		name = metric[metric_index]
		if (seen[name] > 0) {
			printf "metric\t%s\t%d\t%.0f\t%.0f\t%.0f\t%.3f\n", name,
				seen[name], total[name], minimum[name], maximum[name],
				total[name] / seen[name]
		}
	}
	for (result in results) {
		printf "writer_result\t%s\t%d\t-\t-\t-\t-\n", result,
			results[result]
	}
	printf "callbacks\tall\t%d\t-\t-\t-\t-\n", records
}
