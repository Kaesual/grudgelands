-- Single declaration point for the WP40 T2 census run (plan section 6.6).
--
-- The launcher, the shard worker and the milestone-M5 merge all need the same
-- four facts: how `W` is derived, how a shard range and its file name are
-- formed, which decision classes and site counts a Scan-1 seed record may
-- contain, and when a run is allowed to start.  The extreme launcher records
-- in its own comment what a second copy of such a rule costs -- a stale local
-- copy of the shard-name rule aborted a fresh pool launch before any seed was
-- measured -- so every consumer asks this file instead of restating it.
--
-- Nothing here loads geometry or hashes anything by itself: the caller injects
-- `raw_sha256`, which keeps the module usable from the launcher (one process),
-- from a worker (persistent hasher) and from the PUC merge alike.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = dependencies.raw_sha256

	local authority = {}

	local function fail(message)
		error("WP40 T2 census authority: " .. message, 0)
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end

	local function digest_of(text)
		if type(raw_sha256) ~= "function" then fail("no hasher was injected") end
		local raw = raw_sha256(text)
		if type(raw) ~= "string" or #raw ~= 32 then fail("hasher returned no digest") end
		return hex(raw)
	end

	-- Section 6.6.1: eight range-sharded LuaJIT workers.  Section 6.5: nine
	-- hours wall *at eight workers* -- the two numbers belong together, and
	-- splitting them is exactly how a worker-seconds anchor turns into a
	-- wall-time threshold that is wrong by the worker count.
	--
	-- Eight hours until the section-6.5 re-decision of 2026-08-16, which moved
	-- the cap after a second full-`W` start aborted at 28,896 s -- 0.33% over --
	-- while the corpus ETA read 22,728 s.  Eight hours sat inside this host's
	-- own noise band and could not separate an honestly noisy run from a
	-- degraded one; nine hours is the round hour at the geometric middle of the
	-- two measured bands.
	--
	-- Retired as a kill criterion 2026-08-18 (section 6.5, "why the wall cap
	-- retired"): the host is a workstation, so concurrent user load is normal
	-- operation and wall time separates nothing.  The number stays because the
	-- projection stays -- advisory in the progress output and the manifest --
	-- and because the two measured populations it was placed between are what
	-- the replay tests pin the estimator's behaviour against.  Nothing aborts
	-- on it any more; the hard abort is the CPU gate below.
	local worker_count = 8
	local wall_cap_seconds = 9 * 60 * 60
	-- Section 6.6.7: KATs and small explicit ranges run freely.  Everything
	-- above this budget needs the GO token, which replaces the M1 worker's
	-- 64-seed list cap now that range mode exists.
	local free_seed_budget = 64

	-- v3 since M4: the record carries the Scan-1, Scan-3a and Scan-2 rows.  v4
	-- since the stage-reject package (2026-08-17): a record is either the full
	-- per-seed roster or exactly one stage_reject row -- the classified F9
	-- aperture-formation rejects that killed three shards of full-`W` start 3
	-- as hard aborts.  The version is one unit for the whole record -- the
	-- merge and the first-record validator consume complete seed records,
	-- never one scan's rows alone -- and the shard name carries it too, so a
	-- v2 or v3 shard left on disk can never be resumed into a v4 run.
	-- v6 since the Scan-3b/4 census completion (contracts section 9): the v5
	-- rows stay an exact prefix and the record gains the sixteen
	-- transition-incident Bank traces, the bank-incomplete attribution
	-- histogram, the R20/R21 event rows, and -- on Scan-4 members -- the
	-- face, whole and fragment tiers plus the membership row every full
	-- record carries.
	local schema = "grug_wp40_census_scan_v6"
	local shard_schema = "grug_wp40_census_scan_shard_v6"
	local vocabulary_path = "tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua"
	local candidates_path =
		"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv"
	local candidates_schema = "grug_wp40_extreme_measurement_artifact_v3"
	local pool_candidate_count = 4096

	-- The declared class vocabulary of a Scan-1 seed record.  Section 6.6.2
	-- validates a worker's first completed record against exactly this, and the
	-- M5 merge keys the occupied-class table on it, so an unlisted string is a
	-- structural failure here rather than an unnoticed extra row there.
	local classes = {
		prefilter_status = {"discharged", "scanned"},
		edge_kind = {"ordinary", "ordinary_attachment", "transition",
			"transition_attachment"},
		edge_class = {"ordinary_interval_select", "ordinary_interval_zero_reject",
			"ordinary_interval_multi_reject", "transition_interval_select",
			"transition_interval_zero_reject", "transition_interval_multi_reject"},
		attachment_class = {"attachment_equality_select",
			"attachment_adjacent_select", "attachment_distance_reject",
			"attachment_edge_without_interval"},
		junction_pair_class = {"junction_pair_short_raster",
			"junction_pair_not_endpoint", "junction_pair_left_not_eight_connected",
			"junction_pair_right_not_eight_connected", "junction_pair_shared_station",
			"junction_pair_x_cross"},
		-- Scan-2 (M3).  Endpoint rows are the F2 counting tier and the section
		-- 6.2.3 transition stress scalars; edge rows carry the R19 joint
		-- decision under the decided U1/U2 readings; tuple rows are the
		-- per-tuple witnesses, keyed by their read-set envelope digest.
		scan2_endpoint_class = {"scan2_counting_evaluated",
			"scan2_no_selected_interval"},
		scan2_edge_class = {"scan2_exactly_one_complete_select",
			"scan2_zero_complete_reject", "scan2_multi_complete_select",
			"scan2_duplicate_authority_reject", "scan2_selected_below_192_reject",
			"scan2_no_selected_interval"},
		scan2_tuple_class = {"scan2_tuple_complete",
			"scan2_tuple_empty_combined_clip", "scan2_tuple_clip_not_contiguous",
			"scan2_tuple_probe_invalid", "scan2_tuple_probe_wet",
			"scan2_tuple_previous_binding_unsatisfiable",
			"scan2_tuple_bank_incomplete"},
		scan2_flag = {"true", "false"},
		scan2_tuple_mode = {"direct", "diagonal_elbow", "-"},
		-- Scan-3a (M4).  The table-to-vocabulary map lives beside the
		-- projection in partition.lua's census_scan3a comment; what belongs
		-- here is the enumerable class space itself, because the M5
		-- vacuous-branch report is exactly "declared minus realized" over
		-- these lists and can never enumerate a branch some seed realized.
		--
		-- F4, analysis section 3-F4.  Table row 4 (`W` missing / non-unique /
		-- non-diagonal / not same-Bay-only raw+final) is four classes here,
		-- one of which -- W not immediately aperture-included -- that row does
		-- not name.  The wrong-tail-water-side row is decided in trace_bank
		-- rather than at resolution and is evaluated directly by Scan-3a, and
		-- terminal identity drift reads only seed-independent catalog state,
		-- so it is declared and expected vacuous.
		scan3_aperture_class = {"aperture_direct_select", "aperture_tail_select",
			"aperture_d_not_dry_equality_reject",
			"aperture_d_cardinal_water_reject", "aperture_w_not_diagonal_reject",
			"aperture_w_not_bay_water_reject", "aperture_w_foreign_water_reject",
			"aperture_w_not_aperture_included_reject",
			"aperture_shoulder_elbow_count_reject",
			"aperture_tail_wrong_water_side_reject",
			"aperture_terminal_identity_drift_reject"},
		scan3_aperture_mode = {"direct", "diagonal_shoulder", "-"},
		-- F5, analysis section 3-F5, under the 2026-08-16 pair-exclusion
		-- reading: the non-simple/zero-area and `R > 5` rows are per-pair
		-- exclusions counted on the Wing row, not seed rejects, so the only
		-- wedge-shaped reject left is the zero-count one.  The last two classes
		-- have no table row at all (empty distance-layer DAG, finite path
		-- bound) and the Chebyshev one is the section 6.4 refuted frozen
		-- universal.
		scan3_wing_class = {"wing_wedge_valid_select", "wing_missing_k_reject",
			"wing_k_chebyshev_above_four_reject", "wing_no_complete_tail_reject",
			"wing_no_wedge_valid_joint_tail_pair_reject",
			"wing_path_bound_exceeded_reject"},
		-- F3, analysis section 3-F3, over the four head Banks only; the sixteen
		-- transition-incident traces are Scan-3b.  Every class is a
		-- `bay_bank_reject` clause except the select.  Foreign-water contact
		-- has no class of its own: `bay_candidate` absorbs it, so it reaches
		-- the census as a zero-reachable-successor reject.
		scan3_bank_class = {"bank_trace_complete_select",
			"bank_terminal_unresolved_reject", "bank_start_anchor_invalid_reject",
			"bank_target_noncandidate_reject",
			"bank_zero_reachable_successor_reject", "bank_repeated_column_reject",
			"bank_x_cross_reject", "bank_reachability_frame_cap_reject",
			"bank_reachability_stack_cap_reject", "bank_main_trace_cap_reject",
			"bank_trace_envelope_empty_reject", "bank_shoulder_water_side_reject"},
		-- The realized step-class space is the cross product of these two:
		-- eight Moore directions in the declared clockwise base order times the
		-- first failing successor predicate, plus admission.  Six predicates,
		-- not the table's five: "unseen" is two separable bits and the diagonal
		-- X-cross compatibility the table lists only among the rejects is a
		-- successor admission predicate.
		scan3_step_direction = {"east", "southeast", "south", "southwest",
			"west", "northwest", "north", "northeast"},
		scan3_step_outcome = {"admitted", "previous", "seen_state",
			"seen_column", "x_cross", "noncandidate", "water_side"},
		-- Terminal reachability is not a successor predicate at all: trace_bank
		-- tests it only at branch width two or more, so a lone admitted
		-- successor is taken untested.  That asymmetry is the first class here
		-- rather than a silent case of "first pass selected".
		scan3_selection_class = {"single_admitted_untested",
			"branch_first_reachable", "branch_later_reachable",
			"branch_none_reachable", "zero_admitted_successors"},
		-- Section 6.4 / source authority section 7.2.  A negative width would
		-- already have aborted Scan-1 inside exact.bay_segment, so its class
		-- exists to be reported vacuous rather than to be reached.  The
		-- `unbounded` class is the honest fourth case: the sampled stations were
		-- all positive but the exact per-column lower bound could not rule out a
		-- collapse between them, which is a different claim from "measured
		-- positive" and must not be collapsed into it.
		scan3_width_class = {"bay_bank_width_positive",
			"bay_bank_width_zero_event", "bay_bank_width_negative_event",
			"bay_bank_width_unbounded_event"},
		-- Stage rejects (analysis section 3-F9, decided 2026-08-17).  3-F9 has
		-- always declared aperture interval malformation REJECTED -- "wrap,
		-- overlap, second run, dry station, boundary" -- but the deciding
		-- predicates run in build_scan_stage's aperture block, which M1 could
		-- only abort; full-`W` start 3 proved the class occupied at roughly
		-- one seed in 285.  The six classes are the seed-dependent
		-- aperture-block failures; the message-to-class map lives beside
		-- census_scan in partition.lua, and the worker refuses to run when
		-- the two lists disagree.  The mouth-absent and nonmaximal-run sites
		-- stay loud aborts (seed-independent catalog defect; unreachable by
		-- construction) and are declared under unmeasured_branches below.
		stage_reject_class = {"aperture_canonical_wrap_reject",
			"aperture_dry_station_reject", "aperture_overlap_reject",
			"aperture_second_run_reject", "aperture_authored_wrap_reject",
			"aperture_authored_second_run_reject"},
		-- Scan-3b (contracts 9.1).  The outcome vocabulary is the existing
		-- scan3_bank_class -- the contract's own words -- plus the one skip
		-- kind a dead edge forces: a Bank whose transition edge selected no
		-- joint tuple has no terminal to trace from, and "measured" versus
		-- "could not be evaluated" stay different claims (the 6.7 lesson).
		-- The reject values are declared and expected vacuous by discipline:
		-- Scan-2's completion tier proved these Banks complete at the
		-- selected tuple, so an instrumented 3b trace that dies is a loud
		-- worker abort -- a finding, never a column.
		scan3b_bank_class = {"bank_trace_complete_select",
			"bank_terminal_unresolved_reject", "bank_start_anchor_invalid_reject",
			"bank_target_noncandidate_reject",
			"bank_zero_reachable_successor_reject", "bank_repeated_column_reject",
			"bank_x_cross_reject", "bank_reachability_frame_cap_reject",
			"bank_reachability_stack_cap_reject", "bank_main_trace_cap_reject",
			"bank_trace_envelope_empty_reject", "bank_shoulder_water_side_reject",
			"scan3b_bank_not_evaluated"},
		-- The attribution histogram's far-terminal identity (contracts 9.1):
		-- which kind of far terminal the dead Bank had, and its resolved
		-- mode -- direct or shoulder-tail aperture, negative or positive
		-- Wing side; "-" marks a far terminal whose own resolution failed.
		scan3b_far_kind = {"aperture", "wing"},
		scan3b_far_mode = {"direct", "diagonal_shoulder", "negative",
			"positive", "-"},
		-- The two predicted R20/R21 classes, declared so occupancy has a
		-- place to land.  Expected occupancy of both: zero -- a projection,
		-- marked as one, grounded in the v5 measurement that
		-- scan2_zero_complete_reject and every head-Bank reject class read
		-- zero over W.  Nonzero occupancy of either is exactly the named
		-- small-correction-round trigger of plan section 2.
		scan3b_event_class = {"aperture_anchor_dead_event",
			"wing_pair_dead_alternative_event"},
		-- Scan-4 (contracts 9.1/9.2).  Membership is an input list, read
		-- from the committed v2 seed-set artifact by digest plus the v2
		-- manifest's seven admission seeds (the branch-A ruling of 9.2);
		-- "forced" marks a roster top-up run's records.
		scan4_member_kind = {"member", "nonmember"},
		scan4_member_source = {"seed_set", "admission", "forced", "-"},
		-- The face tier: classification per fail site through a message map
		-- beside the projection, anything unmatched re-raised (the
		-- stage-reject precedent).  A face whose upstream arc failed is its
		-- own declared skip kind, never a silent absence.
		-- face_appendix_select (contracts 11.5-C, ruled 2026-08-20;
		-- completed by 11.9) is the DECIDED acceptance of the measured
		-- bay-transition touch family: every repeated station a join-local,
		-- locally non-crossing self-touch inside the pinned window below --
		-- the zero-width filament appendix and the interior-beside pinch
		-- are both accepted forms; the row's detail carries the appendix
		-- and pinch station counts.
		scan4_face_class = {"face_simple_select", "face_appendix_select",
			"face_not_closed_reject",
			"face_wrong_orientation_reject", "face_non_simple_reject",
			"face_composition_reject", "face_upstream_not_evaluated"},
		-- The Whole tier's gate: it runs only when every face of the seed
		-- classifies face_simple_select or face_appendix_select; otherwise
		-- one whole_not_evaluated row names the blocking face.
		scan4_whole_state = {"whole_evaluated", "whole_not_evaluated"},
		-- The H38 row-run interval classes (contracts 9.1).
		-- residual_multi_face_reject (contracts 11.7-B, ruled 2026-08-20;
		-- ring connectivity added by 11.9 family A) is the loud class of
		-- the residue-adoption rule: an unowned dry 4-connected chain whose
		-- candidate owners -- cardinal contact plus, for footprint-ring
		-- stations in the chain, the faces owning the ring-neighbour
		-- stations -- number two or more.  Measured zero over the
		-- 112-pocket anatomy population; expected vacuous, occupancy
		-- measured, never absorbed.
		-- whole_declared_seam_select additionally admits the 11.9 family-C
		-- seam inheritance: a column claimed by exactly two faces, both as
		-- boundary, cardinally adjacent to a declared-seam column of the
		-- identical pair, inherits that declaration; every other
		-- multiplicity stays whole_undeclared_multiplicity_reject.
		scan4_whole_class = {"whole_single_owner_select",
			"whole_declared_seam_select", "whole_gap_reject",
			"whole_undeclared_multiplicity_reject",
			"residual_multi_face_reject"},
		-- The excluded-fragment obligations; the not_evaluated kind fires
		-- only when a face failed to compose, so the fragment's face
		-- ownership could not be measured at all.
		scan4_fragment_class = {"fragment_owned_once_select",
			"fragment_unowned_reject", "fragment_multi_owner_reject",
			"fragment_identity_conflict_reject", "fragment_not_evaluated"},
	}

	-- The F5 per-pair exclusion causes, in the order the Wing row's seven count
	-- columns carry them.  This is census vocabulary, not an implementation
	-- detail: M5's occupied-class table keys pair exclusions on these names, and
	-- the worker refuses to emit a row whose projection-side order disagrees --
	-- which is what stops a new cause from silently vanishing from every shard.
	local wing_exclusion_causes = {"shared_predecessor", "interior_overlap",
		"intra_tail_x_cross", "inter_tail_x_cross",
		"wedge_nonsimple_or_zero_area", "wedge_radius_above_five",
		"wedge_nonwing_water"}
	local class_sets = {}
	for name, values in pairs(classes) do
		local set = {}
		for index = 1, #values do set[values[index]] = true end
		class_sets[name] = set
	end

	-- ------------------------------------------------------------------
	-- The branch universe (plan section 6.2.2, milestone M5).  The
	-- vacuous-branch report is "declared minus realized" over the lists above,
	-- but three distinctions have to travel with the declaration or the report
	-- says something false about a permanent zero.
	-- ------------------------------------------------------------------

	-- Not every declared list is a decision branch.  The `kind` lists below
	-- are row shapes -- an edge is ordinary or transition, a resolution is
	-- direct or elbow -- and an unrealized value there is a coverage note,
	-- never dead policy.
	local class_vocabulary_kind = {
		edge_class = "decision", attachment_class = "decision",
		junction_pair_class = "decision", scan2_endpoint_class = "decision",
		scan2_edge_class = "decision", scan2_tuple_class = "decision",
		scan3_aperture_class = "decision", scan3_wing_class = "decision",
		scan3_bank_class = "decision", scan3_selection_class = "decision",
		scan3_width_class = "decision", scan3_step_outcome = "decision",
		stage_reject_class = "decision",
		scan3b_bank_class = "decision", scan3b_event_class = "decision",
		scan4_face_class = "decision", scan4_whole_state = "decision",
		scan4_whole_class = "decision", scan4_fragment_class = "decision",
		prefilter_status = "kind", edge_kind = "kind", scan2_flag = "kind",
		scan2_tuple_mode = "kind", scan3_aperture_mode = "kind",
		scan3_step_direction = "kind",
		scan3b_far_kind = "kind", scan3b_far_mode = "kind",
		scan4_member_kind = "kind", scan4_member_source = "kind",
	}
	-- The F5 per-pair exclusion causes are a decision vocabulary of their own:
	-- they are counted per Wing rather than carried in a class column, and the
	-- M4 review found two of them dominated, which is exactly the kind of fact
	-- the vacuous report exists to state.
	local exclusion_vocabulary = "wing_exclusion_cause"

	-- Section 6.2.1 makes "a REJECTED row is a finding" the occupied-class
	-- table's whole point, so the verdict is declared rather than inferred
	-- from a name suffix.  Inference would be wrong three ways at once:
	-- `scan2_tuple_probe_wet` and `x_cross` both read like failures and are
	-- both ordinary DECIDED-with-continuation outcomes under the U1/U2
	-- readings, `attachment_edge_without_interval` reads like neither and is a
	-- reject, and the width events are a third verdict that no suffix rule
	-- would separate from the second.
	local class_verdict = {
		ordinary_interval_select = "DECIDED",
		ordinary_interval_zero_reject = "REJECTED",
		ordinary_interval_multi_reject = "REJECTED",
		transition_interval_select = "DECIDED",
		transition_interval_zero_reject = "REJECTED",
		transition_interval_multi_reject = "REJECTED",
		attachment_equality_select = "DECIDED",
		attachment_adjacent_select = "DECIDED",
		attachment_distance_reject = "REJECTED",
		attachment_edge_without_interval = "REJECTED",
		junction_pair_short_raster = "REJECTED",
		junction_pair_not_endpoint = "REJECTED",
		junction_pair_left_not_eight_connected = "REJECTED",
		junction_pair_right_not_eight_connected = "REJECTED",
		junction_pair_shared_station = "REJECTED",
		junction_pair_x_cross = "REJECTED",
		scan2_counting_evaluated = "DECIDED",
		scan2_no_selected_interval = "REJECTED",
		scan2_exactly_one_complete_select = "DECIDED",
		scan2_zero_complete_reject = "REJECTED",
		-- Several complete tuples are a DECIDED selection under the D1
		-- order since the collected correction (plan 7.1, contracts 8.1).
		scan2_multi_complete_select = "DECIDED",
		scan2_duplicate_authority_reject = "REJECTED",
		scan2_selected_below_192_reject = "REJECTED",
		-- Every per-tuple precondition failure is DECIDED-with-continuation:
		-- the tuple dies, enumeration continues, and the seed is rejected only
		-- by the complete-tuple count.  That is the whole content of the U1
		-- and U2 decisions, so binning these as findings would report the two
		-- decisions as thousands of open corrections.
		scan2_tuple_complete = "DECIDED",
		scan2_tuple_empty_combined_clip = "DECIDED",
		scan2_tuple_clip_not_contiguous = "DECIDED",
		scan2_tuple_probe_invalid = "DECIDED",
		scan2_tuple_probe_wet = "DECIDED",
		scan2_tuple_previous_binding_unsatisfiable = "DECIDED",
		scan2_tuple_bank_incomplete = "DECIDED",
		aperture_direct_select = "DECIDED",
		aperture_tail_select = "DECIDED",
		aperture_d_not_dry_equality_reject = "REJECTED",
		aperture_d_cardinal_water_reject = "REJECTED",
		aperture_w_not_diagonal_reject = "REJECTED",
		aperture_w_not_bay_water_reject = "REJECTED",
		aperture_w_foreign_water_reject = "REJECTED",
		aperture_w_not_aperture_included_reject = "REJECTED",
		aperture_shoulder_elbow_count_reject = "REJECTED",
		aperture_tail_wrong_water_side_reject = "REJECTED",
		aperture_terminal_identity_drift_reject = "REJECTED",
		wing_wedge_valid_select = "DECIDED",
		wing_missing_k_reject = "REJECTED",
		wing_k_chebyshev_above_four_reject = "REJECTED",
		wing_no_complete_tail_reject = "REJECTED",
		wing_no_wedge_valid_joint_tail_pair_reject = "REJECTED",
		wing_path_bound_exceeded_reject = "REJECTED",
		bank_trace_complete_select = "DECIDED",
		bank_terminal_unresolved_reject = "REJECTED",
		bank_start_anchor_invalid_reject = "REJECTED",
		bank_target_noncandidate_reject = "REJECTED",
		bank_zero_reachable_successor_reject = "REJECTED",
		bank_repeated_column_reject = "REJECTED",
		bank_x_cross_reject = "REJECTED",
		bank_reachability_frame_cap_reject = "REJECTED",
		bank_reachability_stack_cap_reject = "REJECTED",
		bank_main_trace_cap_reject = "REJECTED",
		bank_trace_envelope_empty_reject = "REJECTED",
		bank_shoulder_water_side_reject = "REJECTED",
		-- Step outcomes and selection classes describe how one successor was
		-- admitted or excluded inside a trace that has its own bank-level
		-- class; none of them rejects a seed.
		admitted = "DECIDED", previous = "DECIDED", seen_state = "DECIDED",
		seen_column = "DECIDED", x_cross = "DECIDED", noncandidate = "DECIDED",
		water_side = "DECIDED",
		single_admitted_untested = "DECIDED",
		branch_first_reachable = "DECIDED",
		branch_later_reachable = "DECIDED",
		branch_none_reachable = "DECIDED",
		zero_admitted_successors = "DECIDED",
		bay_bank_width_positive = "DECIDED",
		bay_bank_width_zero_event = "EVENT",
		bay_bank_width_negative_event = "EVENT",
		bay_bank_width_unbounded_event = "EVENT",
		-- The stage-reject classes.  All REJECTED by 3-F9's own verdict
		-- column: an occupied row here is a finding, located on paper, which
		-- is exactly what full-`W` start 3 could not produce when it died on
		-- the second-run class three shards deep.
		aperture_canonical_wrap_reject = "REJECTED",
		aperture_dry_station_reject = "REJECTED",
		aperture_overlap_reject = "REJECTED",
		aperture_second_run_reject = "REJECTED",
		aperture_authored_wrap_reject = "REJECTED",
		aperture_authored_second_run_reject = "REJECTED",
		-- Scan-3b and Scan-4 (contracts section 9).  The twelve Bank outcome
		-- values above already carry their verdicts; what follows is only
		-- what v6 adds.  The two R20/R21 classes are EVENTs like the width
		-- events: occupancy is the named small-correction trigger, not an
		-- ordinary reject of the seed under measurement.
		scan3b_bank_not_evaluated = "DECIDED",
		aperture_anchor_dead_event = "EVENT",
		wing_pair_dead_alternative_event = "EVENT",
		face_simple_select = "DECIDED",
		face_appendix_select = "DECIDED",
		face_not_closed_reject = "REJECTED",
		face_wrong_orientation_reject = "REJECTED",
		face_non_simple_reject = "REJECTED",
		face_composition_reject = "REJECTED",
		face_upstream_not_evaluated = "DECIDED",
		whole_evaluated = "DECIDED",
		whole_not_evaluated = "DECIDED",
		whole_single_owner_select = "DECIDED",
		whole_declared_seam_select = "DECIDED",
		whole_gap_reject = "REJECTED",
		whole_undeclared_multiplicity_reject = "REJECTED",
		residual_multi_face_reject = "REJECTED",
		fragment_owned_once_select = "DECIDED",
		fragment_unowned_reject = "REJECTED",
		fragment_multi_owner_reject = "REJECTED",
		fragment_identity_conflict_reject = "REJECTED",
		fragment_not_evaluated = "DECIDED",
		-- The seven F5 pair-exclusion causes.  A pair exclusion is a decided
		-- per-pair outcome; the Wing rejects only through its own class.
		shared_predecessor = "DECIDED", interior_overlap = "DECIDED",
		intra_tail_x_cross = "DECIDED", inter_tail_x_cross = "DECIDED",
		wedge_nonsimple_or_zero_area = "DECIDED",
		wedge_radius_above_five = "DECIDED", wedge_nonwing_water = "DECIDED",
	}

	-- Section 6.4's fourth finding kind: a source-asserted all-seed universal
	-- that a single occupied row refutes.  Occupancy here is not "an unusual
	-- DECIDED class", it is a falsified quantifier, and the two must not read
	-- alike in the occupied-class table.
	local refuted_universal = {
		wing_k_chebyshev_above_four_reject = "Chebyshev(K,J) <= 4",
		bay_bank_width_zero_event = "the jittered Bay bank half-width w > 0",
		bay_bank_width_negative_event = "the jittered Bay bank half-width w > 0",
	}

	-- Why a permanent zero is expected, per branch.  "Dominated" and
	-- "untested" are different claims about the same zero and the difference
	-- is what a reader of the vacuous report needs (M4 cold review,
	-- plan section 6.7).
	local branch_notes = {
		aperture_w_foreign_water_reject = {status = "dominated",
			note = "dominated by aperture_w_not_bay_water_reject: " ..
				"w_final_owned_by_bay is tested first and implies not w_foreign_water"},
		wedge_radius_above_five = {status = "dominated",
			note = "dominated by wing_k_chebyshev_above_four_reject: the radius " ..
				"is derived from the same selected K stations the guard rejects, " ..
				"so R = 1 + max Chebyshev(K,J) <= 5 identically"},
		intra_tail_x_cross = {status = "vacuous_by_construction",
			note = "a distance-layer tail visits exactly one column per Chebyshev " ..
				"level, so two of its diagonal steps can never share a 2x2 cell"},
		aperture_terminal_identity_drift_reject = {status = "expected_vacuous",
			note = "reads only seed-independent catalog and aperture source state; " ..
				"the underlying failure stays a loud abort rather than a row"},
		bank_shoulder_water_side_reject = {status = "expected_vacuous",
			note = "needs an aperture shoulder, and the four head Banks have none; " ..
				"at the sixteen Scan-3b Banks the shoulder side is evaluated by " ..
				"Scan-3a's aperture_tail_wrong_water_side_reject from the resolved " ..
				"D,T,W, and an instrumented 3b trace that dies is a loud worker " ..
				"abort (contracts 9.1), so this class stays measured elsewhere"},
		scan3b_bank_not_evaluated = {status = "consequent",
			note = "occupied only where the Bank's transition edge selected no " ..
				"complete joint tuple; the primary finding is that edge's own " ..
				"scan2 row, and v5 measured zero such edges over W"},
		aperture_anchor_dead_event = {status = "in_scope",
			note = "R20 candidate (contracts 9.1): every tuple of an edge dead " ..
				"with the same aperture-far Bank while that incidence resolved " ..
				"direct; expected occupancy zero -- a projection, marked as one " ..
				"-- and nonzero occupancy is the named small-correction trigger"},
		wing_pair_dead_alternative_event = {status = "in_scope",
			note = "R21 candidate (contracts 9.1): a Bank with a Wing far " ..
				"terminal dead at the selected wedge-valid pair while the next " ..
				"wedge-valid pair completes; probed only on the dead condition, " ..
				"expected occupancy zero -- a projection, marked as one"},
		face_non_simple_reject = {status = "in_scope",
			note = "the loud guard of the section-11.5-C two-tier validator " ..
				"as completed by 11.9: an opposing cell diagonal, a repeat " ..
				"outside the pinned join window, a crossing repeat or a " ..
				"station repeated more than twice.  The former F10 occupancy " ..
				"(seeds 2147483648 and 1959553668008863006) moved to " ..
				"face_appendix_select with the 2026-08-20 11.5-C ruling, and " ..
				"the 11.8 family-B occupancy (60 seeds: 41 silverleaf " ..
				"join-distance-11 touches, 19 interior-hugging dips) moved " ..
				"there with the 11.9 ruling -- recorded corrections, named " ..
				"in the commits; occupancy here is expected zero again and " ..
				"nonzero occupancy is a finding outside the measured family"},
		face_appendix_select = {status = "in_scope",
			note = "the section-11.5-C window-guarded acceptance as " ..
				"completed by 11.9 on the fully measured population: every " ..
				"repeated station a join-local, locally non-crossing " ..
				"self-touch (window, non-crossing predicate and the ratified " ..
				"zero-width form condition pinned beside this table with " ..
				"their measurement provenance) -- the zero-width filament " ..
				"appendix and the interior-beside pinch are both accepted " ..
				"forms.  Known occupancy: the two F10 witnesses, the 719 " ..
				"appendix carriers of the section-11.8 union sweep and the " ..
				"60 11.8 family-B seeds; the row's detail carries the " ..
				"appendix and pinch station counts"},
		residual_multi_face_reject = {status = "expected_vacuous",
			note = "the loud class of the section-11.7-B residue-adoption " ..
				"rule (ring connectivity added by 11.9 family A): an unowned " ..
				"dry 4-connected chain whose candidate owners -- cardinal " ..
				"contact plus ring-neighbour ownership at footprint-ring " ..
				"stations -- number two or more.  The 2026-08-20 attachment-" ..
				"anatomy sweep measured every surviving pocket touching " ..
				"exactly one face (112/112, zero multi-face, zero diagonal-" ..
				"only) and the A/C micro-anatomy measured exactly one ring " ..
				"link per pinched fragment (8/8), so occupancy is expected " ..
				"zero -- a projection, marked as one -- and nonzero " ..
				"occupancy is a finding, never absorbed"},
		face_upstream_not_evaluated = {status = "consequent",
			note = "the face's upstream arc failed to assemble; the arc's " ..
				"verbatim failure travels in the face row's detail and the " ..
				"finding is that failure, not this skip kind"},
		whole_not_evaluated = {status = "consequent",
			note = "the Whole tier runs only when every face classifies " ..
				"face_simple_select or face_appendix_select (the 11.5-C " ..
				"amendment); this row names the blocking face, whose own " ..
				"reject row is the primary finding -- measured and " ..
				"could-not-be-evaluated stay different claims (the 6.7 lesson)"},
		fragment_not_evaluated = {status = "consequent",
			note = "a zone face failed to compose, so the fragment's face " ..
				"ownership could not be measured; the primary finding is the " ..
				"face row"},
		aperture_tail_wrong_water_side_reject = {status = "in_scope",
			note = "decided in trace_bank but evaluated in Scan-3a from the " ..
				"resolved D,T,W, so it is measured here rather than deferred"},
		scan2_no_selected_interval = {status = "consequent",
			note = "occupied only where the same edge already rejected at F1; " ..
				"the primary finding is that edge row"},
		bay_bank_width_unbounded_event = {status = "in_scope",
			note = "not a refuted universal but a failed proof: every sampled " ..
				"station stayed positive and the exact per-column bound could not " ..
				"rule out a collapse between them"},
		-- The stage-reject classes (2026-08-17).  One is known occupied
		-- before the first v4 run; the note travels with it so the occupancy
		-- reads as the expected finding rather than a surprise.
		aperture_second_run_reject = {status = "in_scope",
			note = "the first occupied stage class: full-W start 3 died here " ..
				"deterministically at ~1/285 seeds (least witness " ..
				"343674299183575008, the fifth KAT seed); the 'wrapping' arm of " ..
				"its message is dominated by aperture_canonical_wrap_reject, " ..
				"which fires first when the run touches the canonical seam"},
		aperture_canonical_wrap_reject = {status = "in_scope",
			note = "the run reaches the canonical array seam; the guard's " ..
				"mouth-relative arms are unreachable -- first and last start at " ..
				"the mouth index and move monotonically"},
		aperture_dry_station_reject = {status = "in_scope",
			note = "realizable only by the mouth station itself: the expansion " ..
				"loops admit Bay members only, so no other included station can " ..
				"fail the predicate"},
		aperture_overlap_reject = {status = "in_scope",
			note = "fires on the later aperture of the pair in source order; " ..
				"the partner id is in the verbatim detail"},
		aperture_authored_wrap_reject = {status = "in_scope",
			note = "the same F9 wrap in the authored index space, independently " ..
				"reachable -- the authored seam sits elsewhere than the " ..
				"canonical one, and the guard keeps a two-station shoulder " ..
				"margin for the bank_before/after_previous neighborhood"},
		aperture_authored_second_run_reject = {status = "in_scope",
			note = "the authored-order counterpart of aperture_second_run_reject; " ..
				"the census follows the procedure's granularity, and the two " ..
				"orders fail independently"},
	}

	-- Section-3 table rows that the procedure decides but no emitted class
	-- names.  They are derivable from counting columns, so the census reports
	-- their occupancy rather than pretending the tables have no such row.
	local derived_branches = {
		{branch = "edge_singleton_interval", vocabulary = "edge_class",
			verdict = "DECIDED", row = "edge", predicate = "singleton_count > 0",
			note = "analysis 3-F1 'singleton interval' -- it is E for both " ..
				"obligations and does not qualify; the Slot-30 witness"},
		{branch = "scan2_incidence_not_eligible",
			vocabulary = "scan2_endpoint_class", verdict = "DECIDED",
			row = "scan2_endpoint",
			predicate = "finish - first + 1 - eligible_count > 0",
			note = "analysis 3-F2 'eligible incidence without adjacent-away " ..
				"station' -- the counting tier encodes it in its loop bounds, so " ..
				"it has no row and is the difference between the selected " ..
				"interval length and the eligible count"},
		{branch = "junction_pair_pass", vocabulary = "junction_pair_class",
			verdict = "DECIDED", row = "junction", predicate = "pass_count > 0",
			note = "analysis 3-F7 'pair disjoint, or sharing only J' -- only " ..
				"failing pairs emit a junction_pair row, so the passing class is " ..
				"read off the junction row's pass count"},
	}

	-- Section 6.2.3, decided 2026-08-16 per site kind: the 153 structural sites
	-- and the stress scalars whose per-site minimum and maximum name the
	-- extremal seeds of Scan-4's input set.  Declared here because the count is
	-- load-bearing -- an artifact silently covering 137 of 153 sites is exactly
	-- the failure this roster exists to make impossible -- and because sixteen
	-- of the twenty Banks are Scan-3b and have to be reported open rather than
	-- quietly dropped from the total.
	local extremal_families = {
		{family = "edge", row = "edge", sites = 61,
			scalars = {"topology_ceiling_nodes", "max_abs_scalar_q"}},
		{family = "perimeter", row = "perimeter", sites = 2,
			scalars = {"topology_ceiling_nodes", "max_abs_scalar_q"},
			excluded_site = "perimeter_holy_grounds",
			excluded_reason = "the fixed Holy band carries zero displacement on " ..
				"every seed, so both its scalars are constant and an extremal " ..
				"seed for it would be an artifact of the tie rule; section 6.2.3 " ..
				"counts 63 edge and perimeter records, not 64"},
		{family = "transition_endpoint", row = "scan2_endpoint", sites = 8,
			scalars = {"eligible_count", "success_count"}},
		{family = "aperture_incidence", row = "aperture", sites = 8,
			scalars = {"d_scalar_q", "w_scalar_q", "a_scalar_q"}},
		{family = "wing", row = "scan3_wing", sites = 8,
			scalars = {"chebyshev_k_j", "selected_raw_rank"}},
		-- Complete since Scan-3b (contracts 9.1): the four head Banks arrive
		-- on scan3_bank rows, the sixteen transition-incident Banks on
		-- scan3b_bank rows, and the two per-Bank scalars close the last
		-- sixteen open sites of the 153-site roster.
		{family = "bank", row = "scan3_bank", rows = {"scan3_bank", "scan3b_bank"},
			sites = 20, scalars = {"step_count", "max_frames"}},
		{family = "junction", row = "junction", sites = 38,
			scalars = {"min_clearance"}},
		{family = "attachment", row = "attachment", sites = 8,
			scalars = {"distance"}},
	}
	local extremal_site_total = 153
	do
		local total = 0
		for index = 1, #extremal_families do
			total = total + extremal_families[index].sites
		end
		if total ~= extremal_site_total then
			fail("the extremal roster covers " .. total .. " sites, section 6.2.3 " ..
				"names " .. extremal_site_total)
		end
	end
	-- The one scalar section 6.2.3 names that no column carries directly: the
	-- Wing guard is per side, so the Wing's own `Chebyshev(K,J)` is the larger
	-- of the two sides -- the value the `<= 4` universal is asserted against.
	local derived_scalars = {
		chebyshev_k_j = {row = "scan3_wing", rule = "max",
			from = {"negative_chebyshev", "positive_chebyshev"}},
	}

	-- Section 6.2.3's flagged term, as predicates over emitted columns.  The
	-- fragment case is analysis 3-F8's "nonselected intervals or controls exist
	-- at all": the census witnesses it as an attachment whose edge realized a
	-- second dry interval, which is the excluded dry fragment itself and the
	-- shape Slot 30 was the first seed to realize.
	--
	-- A hit is reported against the row's declared *site*, not against one
	-- named column: an aperture incidence is `(id, side)`, and a flagged seed
	-- whose reason names only the aperture cannot say which of its two
	-- incidences realized the tail mode.
	local flag_rules = {
		{flag = "fills", row = "bay", column = "fill_count", test = "at_least",
			value = 1},
		{flag = "tail_mode", row = "scan3_aperture", column = "class",
			test = "equals", value = "aperture_tail_select"},
		{flag = "multi_interval", row = "edge", column = "interval_count",
			test = "at_least", value = 2},
		{flag = "two_or_more_candidates", row = "scan2_endpoint",
			column = "success_count", test = "at_least", value = 2},
		{flag = "branch", row = "scan3_bank", column = "branch_step_count",
			test = "at_least", value = 1},
		{flag = "fragment", row = "attachment", column = "interval_count",
			test = "at_least", value = 2},
		-- The stage-reject flag (decided 2026-08-17).  A stage-rejected seed
		-- is a rare-class realizer by definition, and once the collected
		-- correction closes its class it is exactly the stressed geometry
		-- Scan-4 exists to look at.  "any" tests row presence; the class is
		-- named by the occupied-class table, the flag detail names the site.
		{flag = "stage_reject", row = "stage_reject", column = "class",
			test = "any"},
		-- The detached-shoulder admission flag (contracts 9.2, RULED
		-- 2026-08-19: branch A).  At 7 of 4,123 the rarest occupied
		-- configuration over W; the flag vocabulary predated the class the
		-- collected correction created, and this rule closes that hole for
		-- good: the flag fires wherever the v5/v6 aperture row records an
		-- admitted detached station.  "present" tests the column against
		-- the "-" placeholder.
		{flag = "detached_shoulder_admission", row = "scan3_aperture",
			column = "detached", test = "present"},
	}

	-- Section-3 table rows that this record cannot witness at all.  Reporting
	-- them as vacuous would be a false claim about coverage, so they are
	-- declared as what they are: not measured by the v3 record.
	local unmeasured_branches = {
		{branch = "attachment_distance_tie", vocabulary = "attachment_class",
			reason = "the attachment row retains the chosen canonical station " ..
				"index but no tie indicator, so whether the canonical-index " ..
				"tie-break ever fired is not decidable from a v3 record"},
		{branch = "wing_pair_wrong_side", vocabulary = exclusion_vocabulary,
			reason = "collect_paths emits strict-side stations only, so the " ..
				"table's side clause has no counted cause to be zero in"},
		{branch = "junction_roster_and_departure_record_rejects",
			vocabulary = "junction_pair_class",
			reason = "analysis 3-F7's Stage-1 roster and departure-record rows " ..
				"are seed-independent stage validations that abort loudly; no " ..
				"census class covers them by design"},
		-- The two aperture-block fail sites the stage-reject vocabulary
		-- deliberately leaves out (decided 2026-08-17), stated here so 3-F9's
		-- row inventory stays complete in the coverage report without a class
		-- that a code fault could quietly occupy.
		{branch = "aperture_mouth_absent_abort", vocabulary = "stage_reject_class",
			reason = "seed-independent by construction: Bay centrelines are " ..
				"no-jitter displacement sources, so the declared mouth sits on " ..
				"the final perimeter on every seed or the catalog is wrong -- a " ..
				"structural defect that aborts loudly rather than becoming a " ..
				"row; the authored-order lookup is dominated by the canonical " ..
				"one over the same point set"},
		{branch = "aperture_nonmaximal_run_abort",
			vocabulary = "stage_reject_class",
			reason = "analysis 3-F9's 'boundary stations passing it' is " ..
				"unreachable by construction -- the expansion loops terminate " ..
				"exactly where the Bay predicate fails -- so the check is " ..
				"defensive and a hit would be an evaluation-determinism fault, " ..
				"not a seed configuration; it aborts loudly rather than " ..
				"becoming a row"},
	}

	-- Per-seed site roster and row width.  `count` nil means the row kind is
	-- occupancy-driven (a junction-pair reject is only emitted when a pair
	-- fails), everything else must appear exactly `count` times per seed:
	-- "every site present" from section 6.6.2 is a count, not a hope.
	--
	-- `columns` names the same fields the worker emits positionally, and
	-- `site` names the seed-independent site identity inside them.  The merge
	-- cannot read a field without knowing its index, and a private copy of
	-- these indices in the merge is exactly the second copy of a rule this
	-- file exists to prevent; `fields` stays declared beside the names and is
	-- cross-checked against them below, so a name list that drifts from the
	-- frozen width fails at load rather than at the artifact.
	local record_rows = {
		{tag = "edge", count = 61, fields = 13, class_field = 5,
			class_set = "edge_class", extra_field = 4, extra_set = "edge_kind",
			site = {"id"},
			columns = {"tag", "seed", "id", "kind", "class", "interval_count",
				"qualifying_count", "singleton_count", "selected_first",
				"selected_finish", "station_count", "topology_ceiling_nodes",
				"max_abs_scalar_q"}},
		{tag = "perimeter", count = 3, fields = 6, site = {"id"},
			columns = {"tag", "seed", "id", "station_count",
				"topology_ceiling_nodes", "max_abs_scalar_q"}},
		{tag = "aperture", count = 8, fields = 16, site = {"id", "side"},
			columns = {"tag", "seed", "id", "side", "d_x", "d_z", "d_scalar_q",
				"d_sample_distance", "w_x", "w_z", "w_scalar_q",
				"w_sample_distance", "a_x", "a_z", "a_scalar_q",
				"a_sample_distance"}},
		{tag = "attachment", count = 8, fields = 13, class_field = 6,
			class_set = "attachment_class", site = {"id"},
			columns = {"tag", "seed", "id", "edge_id", "endpoint", "class",
				"distance", "interval_count", "e_x", "e_z", "a_x", "a_z",
				"canonical_index"}},
		{tag = "junction", count = 38, fields = 7, site = {"id"},
			columns = {"tag", "seed", "id", "pair_count", "pass_count",
				"fail_count", "min_clearance"}},
		{tag = "junction_pair", fields = 6, class_field = 6,
			class_set = "junction_pair_class",
			site = {"junction_id", "left_edge", "right_edge"},
			columns = {"tag", "seed", "junction_id", "left_edge", "right_edge",
				"class"}},
		{tag = "bay", count = 4, fields = 5, site = {"id"},
			columns = {"tag", "seed", "id", "fill_count", "fill_points"}},
		{tag = "scan2_endpoint", count = 8, fields = 14, class_field = 6,
			class_set = "scan2_endpoint_class", extra_field = 7,
			extra_set = "scan2_flag", site = {"id"},
			columns = {"tag", "seed", "id", "edge_id", "endpoint", "class",
				"flagged", "first", "finish", "eligible_count", "success_count",
				"direct_count", "elbow_count", "successes"}},
		{tag = "scan2_edge", count = 6, fields = 11, class_field = 4,
			class_set = "scan2_edge_class", extra_field = 5,
			extra_set = "scan2_flag", site = {"edge_id"},
			-- compile_agreement is the v5 cross-check column (contracts 8.5):
			-- "agrees" on a DECIDED selection -- the worker aborts on any
			-- disagreement rather than recording one -- and the compile
			-- outcome on a rejected class.
			columns = {"tag", "seed", "edge_id", "class", "flagged",
				"tuple_count", "complete_count", "duplicate_count",
				"selected_tuple_index", "selected_station_count",
				"compile_agreement"}},
		{tag = "scan2_tuple", fields = 16, class_field = 5,
			class_set = "scan2_tuple_class", extra_field = 7,
			extra_set = "scan2_tuple_mode", extra2_field = 11,
			extra2_set = "scan2_tuple_mode", site = {"edge_id"},
			-- The tuple index is a per-seed enumeration ordinal and never a
			-- site: the same index names different incidence pairs on
			-- different seeds.  `key` is the read-set envelope digest, the one
			-- place in this record where section 6.1's configuration key
			-- survives as bytes.
			columns = {"tag", "seed", "edge_id", "tuple_index", "class",
				"from_index", "from_mode", "from_point", "from_previous",
				"to_index", "to_mode", "to_point", "to_previous",
				"probe_station_count", "key", "detail"}},
		-- Scan-3a (M4).  Eight aperture incidences, eight Wings, four head
		-- Banks and four Bay bank-width rows are per-seed rosters; the step and
		-- selection rows are occupancy-driven, since a direction/outcome pair
		-- no step realized has no row and that absence is the measurement.
		{tag = "scan3_aperture", count = 8, fields = 15, class_field = 5,
			class_set = "scan3_aperture_class", extra_field = 6,
			extra_set = "scan3_aperture_mode", site = {"id", "side"},
			-- detached is the v5 D2 admission column (plan 7.2): the
			-- authored-order detached shoulder station of this side, "-"
			-- where the admission did not fire.
			columns = {"tag", "seed", "id", "side", "class", "mode", "d", "t",
				"w", "selected_elbow", "water_side_ok", "bank_id",
				"terminal_index", "detail", "detached"}},
		{tag = "scan3_wing", count = 8, fields = 30, class_field = 5,
			class_set = "scan3_wing_class", site = {"id"},
			columns = {"tag", "seed", "id", "bay_id", "class",
				"negative_k_count", "positive_k_count", "negative_k",
				"positive_k", "negative_chebyshev", "positive_chebyshev",
				"negative_path_count", "positive_path_count",
				"negative_tail_length", "positive_tail_length", "radius",
				"path_bound", "raw_pair_count", "structural_pair_count",
				"wedge_valid_count", "selected_raw_rank",
				"selected_structural_rank", "exclusion_shared_predecessor",
				"exclusion_interior_overlap", "exclusion_intra_tail_x_cross",
				"exclusion_inter_tail_x_cross",
				"exclusion_wedge_nonsimple_or_zero_area",
				"exclusion_wedge_radius_above_five",
				"exclusion_wedge_nonwing_water", "detail"}},
		{tag = "scan3_bank", count = 4, fields = 12, class_field = 5,
			class_set = "scan3_bank_class", site = {"id"},
			columns = {"tag", "seed", "id", "bay_id", "class", "step_count",
				"station_count", "max_frames", "max_stack", "branch_step_count",
				"multi_reachable_step_count", "detail"}},
		{tag = "scan3_width", count = 4, fields = 20, class_field = 4,
			class_set = "scan3_width_class", site = {"id"},
			columns = {"tag", "seed", "id", "class", "station_count",
				"min_numerator", "min_length", "min_width_nodes", "min_segment",
				"min_station", "min_x", "min_z", "min_delta_nodes",
				"jittered_numerator", "jittered_length", "jittered_width_nodes",
				"jittered_delta_nodes", "min_delta", "max_delta",
				"column_bound_nodes"}},
		{tag = "scan3_step", fields = 6, class_field = 5,
			class_set = "scan3_step_outcome", extra_field = 4,
			extra_set = "scan3_step_direction", site = {"bank_id", "direction"},
			columns = {"tag", "seed", "bank_id", "direction", "outcome",
				"count"}},
		{tag = "scan3_selection", fields = 8, class_field = 4,
			class_set = "scan3_selection_class", site = {"bank_id"},
			columns = {"tag", "seed", "bank_id", "class", "count", "max_width",
				"multi_reachable", "unknown_reachable"}},
		-- The stage-reject record (v4).  A seed whose build_scan_stage dies in
		-- the aperture block on a classified 3-F9 malformation emits exactly
		-- one of these and nothing else; validate_record below makes the two
		-- record shapes mutually exclusive.  `stage_shape` marks the row as
		-- v4's second record shape -- never part of the full per-seed roster
		-- -- and the synthetic record builders in the gate test and the gates
		-- script filter on it rather than on the tag name.  `detail` is the
		-- verbatim fail message -- section 6.3's configuration bytes for this
		-- family: class, site, seed and the message suffice to write and test
		-- the correction, because the seed reproduces solo and
		-- deterministically at ordinary per-seed cost.
		{tag = "stage_reject", fields = 5, class_field = 4, stage_shape = true,
			class_set = "stage_reject_class", site = {"site"},
			columns = {"tag", "seed", "site", "class", "detail"}},
		-- ------------------------------------------------------------------
		-- v6 rows (contracts section 9).  Everything above is the exact v5
		-- prefix; the worker emits what follows after the scan3_selection
		-- block, in this declaration order.
		-- ------------------------------------------------------------------
		-- Scan-3b: the sixteen transition-incident Bank traces, one row per
		-- Bank per seed, from the terminals of the selected joint tuple.
		{tag = "scan3b_bank", count = 16, fields = 16, class_field = 5,
			class_set = "scan3b_bank_class", extra_field = 8,
			extra_set = "scan3b_far_kind", extra2_field = 9,
			extra2_set = "scan3b_far_mode", site = {"id"},
			columns = {"tag", "seed", "id", "bay_id", "class", "edge_id",
				"endpoint", "far_kind", "far_mode", "step_count", "station_count",
				"max_frames", "max_stack", "branch_step_count",
				"multi_reachable_step_count", "detail"}},
		{tag = "scan3b_step", fields = 6, class_field = 5,
			class_set = "scan3_step_outcome", extra_field = 4,
			extra_set = "scan3_step_direction", site = {"bank_id", "direction"},
			columns = {"tag", "seed", "bank_id", "direction", "outcome",
				"count"}},
		{tag = "scan3b_selection", fields = 8, class_field = 4,
			class_set = "scan3_selection_class", site = {"bank_id"},
			columns = {"tag", "seed", "bank_id", "class", "count", "max_width",
				"multi_reachable", "unknown_reachable"}},
		-- The bank-incomplete attribution histogram substrate: one row per
		-- (edge endpoint, dead Bank, far kind/mode) with the per-seed count
		-- of scan2_tuple_bank_incomplete tuples attributing that Bank.
		-- First-fail semantics: only the first-dying Bank of a tuple is
		-- attributed, so counts are lower bounds conditioned on the
		-- evaluation order (the stage-reject precedent, stated not implied).
		{tag = "scan3b_attribution", fields = 8, extra_field = 6,
			extra_set = "scan3b_far_kind", extra2_field = 7,
			extra2_set = "scan3b_far_mode",
			site = {"edge_id", "endpoint", "bank_id"},
			columns = {"tag", "seed", "edge_id", "endpoint", "bank_id",
				"far_kind", "far_mode", "count"}},
		-- R20/R21 occupancy rows (EVENTs), emitted only when a classifier
		-- fires; the site is the aperture incidence (R20) or the Wing side
		-- (R21).
		{tag = "scan3b_event", fields = 5, class_field = 4,
			class_set = "scan3b_event_class", site = {"site"},
			columns = {"tag", "seed", "site", "class", "detail"}},
		-- Scan-4 (contracts 9.1/9.2).  Every full record carries exactly one
		-- membership row; the face, whole, whole-interval and fragment rows
		-- appear exactly on member records, which validate_record enforces
		-- below.
		{tag = "scan4_membership", count = 1, fields = 5, extra_field = 3,
			extra_set = "scan4_member_kind", extra2_field = 4,
			extra2_set = "scan4_member_source", site = {"member"},
			columns = {"tag", "seed", "member", "source", "detail"}},
		{tag = "scan4_face", fields = 6, class_field = 4,
			class_set = "scan4_face_class", site = {"id"},
			columns = {"tag", "seed", "id", "class", "station_count",
				"detail"}},
		{tag = "scan4_whole", fields = 11, class_field = 3,
			class_set = "scan4_whole_state", site = {"class"},
			columns = {"tag", "seed", "class", "blocking_face", "columns",
				"planned_water_columns", "dry_columns", "g", "o", "r", "m"}},
		{tag = "scan4_whole_interval", fields = 7, class_field = 4,
			class_set = "scan4_whole_class", site = {"site"},
			columns = {"tag", "seed", "site", "class", "interval_count",
				"column_count", "witness"}},
		{tag = "scan4_fragment", fields = 11, class_field = 5,
			class_set = "scan4_fragment_class", site = {"edge_id"},
			columns = {"tag", "seed", "edge_id", "station", "class", "x", "z",
				"land_count", "bank_count", "face_count", "terminal_identity"}},
	}
	local record_row_by_tag = {}
	for index = 1, #record_rows do
		local layout = record_rows[index]
		record_row_by_tag[layout.tag] = layout
		if #layout.columns ~= layout.fields then
			fail("row " .. layout.tag .. " declares " .. #layout.columns ..
				" column names for " .. layout.fields .. " fields")
		end
		local column_index = {}
		for column = 1, #layout.columns do
			local name = layout.columns[column]
			if column_index[name] then
				fail("row " .. layout.tag .. " names the column " .. name .. " twice")
			end
			column_index[name] = column
		end
		if column_index.tag ~= 1 or column_index.seed ~= 2 then
			fail("row " .. layout.tag .. " must open with tag and seed")
		end
		if layout.class_field and column_index.class ~= layout.class_field and
				column_index.outcome ~= layout.class_field then
			fail("row " .. layout.tag .. " names no column at its class field")
		end
		for site_index = 1, #layout.site do
			if not column_index[layout.site[site_index]] then
				fail("row " .. layout.tag .. " has no column " ..
					layout.site[site_index] .. " to key its site on")
			end
		end
		layout.column_index = column_index
	end
	local prefilter_edge_count = 61

	-- Reading a field by name, which is the only way the merge touches a row.
	local function field(tag, fields, name)
		local layout = record_row_by_tag[tag]
		if not layout then fail("unknown row tag " .. tostring(tag)) end
		local index = layout.column_index[name]
		if not index then
			fail("row " .. tag .. " has no column named " .. tostring(name))
		end
		local value = fields[index]
		if value == nil then fail("row " .. tag .. " is truncated at " .. name) end
		return value
	end

	-- The seed-independent site identity of one row, as the merge keys it.
	local function site_of(tag, fields)
		local layout = record_row_by_tag[tag]
		if not layout then fail("unknown row tag " .. tostring(tag)) end
		local parts = {}
		for index = 1, #layout.site do
			parts[index] = field(tag, fields, layout.site[index])
		end
		return table.concat(parts, ":")
	end

	-- The complete declared branch universe, in one deterministic order:
	-- every value of every decision vocabulary, plus the seven F5 pair
	-- exclusion causes, each with its verdict and whatever the M3/M4 reviews
	-- recorded about why its zero would be expected.  The M5 vacuous-branch
	-- report is this list minus what the shards realized.
	local function branch_universe()
		local names = {}
		for name in pairs(classes) do names[#names + 1] = name end
		table.sort(names)
		local universe = {}
		local function add(vocabulary, branch)
			local verdict = class_verdict[branch]
			if not verdict then
				fail("declared branch " .. branch .. " has no verdict")
			end
			local note = branch_notes[branch]
			universe[#universe + 1] = {vocabulary = vocabulary, branch = branch,
				verdict = verdict, status = note and note.status or "in_scope",
				note = note and note.note or "",
				universal = refuted_universal[branch]}
		end
		for index = 1, #names do
			local name = names[index]
			if class_vocabulary_kind[name] == nil then
				fail("class list " .. name .. " is neither a decision nor a kind")
			end
			if class_vocabulary_kind[name] == "decision" then
				local values = classes[name]
				for value_index = 1, #values do add(name, values[value_index]) end
			end
		end
		for index = 1, #wing_exclusion_causes do
			add(exclusion_vocabulary, wing_exclusion_causes[index])
		end
		return universe
	end

	-- Shards are per-seed intermediates, which section 6.3 forbids committing,
	-- so they live under the gitignored results tree; only the five merged
	-- artifacts reach fixtures/t2_census/.  The name shares no prefix with
	-- either pool shard pattern, and `assert_disjoint_from_pool` below proves
	-- that instead of asserting it in prose (section 6.6.1).
	local shard_directory = "tools/wp40/results/t2_census"
	local shard_pattern = "census-scan-v6-%04d-%04d.tsv"
	-- Earlier shard names a v6 shard must never collide with: both pool
	-- patterns and the two earlier census generations, which stay untouched
	-- on disk as the prior records (contracts 9.3).
	local pool_shard_patterns = {"shard-luajit-v3-%04d-%04d.tsv",
		"shard-luajit-%04d-%04d.tsv", "census-scan-v4-%04d-%04d.tsv",
		"census-scan-v5-%04d-%04d.tsv"}

	-- Every file whose bytes can move a census row.  The worker pins these
	-- before it loads them and re-reads them before it publishes: the extreme
	-- launcher buys the same guarantee with a per-shard `git archive` of the
	-- whole tree, which is eight full exports here for one property.
	local module_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua",
		"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua",
		"tools/wp40/t2_census_authority.lua",
		"tools/wp40/t2_census_hasher.lua",
		"tools/wp40/t2_census_worker.lua",
	}

	-- The launcher-side files that decide whether and how a run starts.  A
	-- full-`W` run requires these and every module path above to be committed
	-- and unmodified, which is what makes the commit and tree in a shard header
	-- a statement about the code that produced it.
	-- The probe is one of them since 2026-08-18: it does not run during a
	-- census, but the CPU budget the launcher aborts on is its output, and a
	-- measurement no commit can reproduce is not evidence.
	local launcher_paths = {
		"tools/wp40/run_t2_census.sh",
		"tools/wp40/run_t2_census_probe.sh",
		"tools/wp40/t2_census_gate.lua",
		"tools/wp40/t2_census_probe_contention.lua",
		"tools/wp40/t2_census_sha_server.py",
	}

	-- Section 6.5's measured CPU gate, written by run_t2_census_probe.sh and
	-- read by the launcher.  Deliberately *not* a launcher path: it is a
	-- measurement of this host on a day, not authority bytes a shard header can
	-- claim, and results/ is gitignored for exactly that reason.  It is dated
	-- instead, and a run refuses a conf older than the commit it is about to be
	-- reproducible from -- a margin measured before the code that would spend it
	-- is a number about a different program.
	local cpu_gate_conf_path = "tools/wp40/results/census-cpu-gate.conf"
	local cpu_gate_conf_keys = {"ANCHOR_CPU_SECONDS", "CONTENTION_MARGIN",
		"LIVENESS_X_CPU_SECONDS", "PROBE_DATE"}

	local function positive_integer(value, label)
		if type(value) ~= "number" or value % 1 ~= 0 or value < 0 then
			fail(label .. " is not a nonnegative integer")
		end
		return value
	end

	local function census_shard_path(first, last)
		positive_integer(first, "shard first index")
		positive_integer(last, "shard last index")
		if last < first then fail("shard range is empty") end
		if first > 99999 or last > 99999 then fail("shard range is out of range") end
		return shard_directory .. "/" .. shard_pattern:format(first, last)
	end

	local function assert_disjoint_from_pool(first, last)
		local name = shard_pattern:format(first, last)
		for index = 1, #pool_shard_patterns do
			local pool_name = pool_shard_patterns[index]:format(first, last)
			if name == pool_name then fail("census shard name collides with a pool shard") end
			local stem = pool_name:match("^(.-)%-%d")
			if stem and name:find(stem, 1, true) then
				fail("census shard name contains the pool shard stem " .. stem)
			end
		end
		return true
	end

	local function validate_census_shard_path(path, first, last)
		if type(path) ~= "string" then fail("shard path is not text") end
		if path ~= census_shard_path(first, last) then
			fail("shard path is not the canonical census path for its range")
		end
		assert_disjoint_from_pool(first, last)
		return true
	end

	-- A free run (KAT or a small explicit range) writes wherever the caller
	-- points it, but it must never land on a shard name: a 3-seed file sitting
	-- at a shard path would be resumed as a finished shard.
	local function validate_free_output_path(path)
		if type(path) ~= "string" or path == "" then fail("output path is not text") end
		local name = path:match("([^/]+)$") or path
		if name:match("^census%-scan%d*%-v%d+%-%d+%-%d+%.tsv$") then
			fail("a free census run must not write a shard file name")
		end
		if path:find(shard_directory, 1, true) then
			fail("a free census run must not write into the shard directory")
		end
		return true
	end

	-- Section 6.6.1: eight ranges covering W exactly once.  |W| is not a
	-- multiple of eight -- unlike the pool's clean 512s -- so the remainder goes
	-- to the leading shards and the cover is asserted, never assumed.
	local function shard_ranges(total)
		positive_integer(total, "W size")
		if total < worker_count then fail("W is smaller than the worker count") end
		local base = math.floor(total / worker_count)
		local remainder = total - base * worker_count
		local ranges, first = {}, 0
		for index = 1, worker_count do
			local size = base + (index <= remainder and 1 or 0)
			ranges[index] = {first = first, last = first + size - 1, size = size}
			first = first + size
		end
		if first ~= total then fail("shard ranges do not cover W") end
		return ranges
	end

	-- What a shard must agree on to be resumable: the bytes that can move a
	-- row, not the commit that happened to be checked out.  Keying resume on
	-- the commit would invalidate every finished shard the moment an unrelated
	-- docs commit landed mid-run.
	local function module_digest(read_file)
		if type(read_file) ~= "function" then fail("module digest needs a reader") end
		local lines = {}
		for index = 1, #module_paths do
			local path = module_paths[index]
			local bytes = read_file(path)
			if type(bytes) ~= "string" then fail("module bytes are missing for " .. path) end
			lines[index] = path .. "\t" .. digest_of(bytes)
		end
		return digest_of(table.concat(lines, "\n") .. "\n")
	end

	-- A gated range is one of those eight and nothing else.  Without this a
	-- single GO-token worker could take all of `W` in one process -- eight
	-- times the wall time the cost gate is written against.
	local function validate_shard_range(first, last, total)
		local ranges = shard_ranges(total)
		for index = 1, #ranges do
			if ranges[index].first == first and ranges[index].last == last then
				return index
			end
		end
		fail("range " .. tostring(first) .. ".." .. tostring(last) ..
			" is not one of the " .. worker_count .. " canonical shard ranges of W")
	end

	-- Canonical unsigned-64 decimal order: no leading zeros, so a shorter text
	-- is the smaller number and equal lengths compare lexicographically.  The
	-- seeds never pass through a Lua number.
	local function decimal_less(left, right)
		if #left ~= #right then return #left < #right end
		return left < right
	end

	local function validate_seed_text(seed, label)
		if type(seed) ~= "string" or not seed:match("^%d+$") then
			fail(label .. " is not decimal text")
		end
		if seed ~= "0" and seed:match("^0") then
			fail(label .. " has a leading zero")
		end
		if #seed > 20 or #seed == 20 and seed > "18446744073709551615" then
			fail(label .. " exceeds the unsigned 64-bit range")
		end
		return seed
	end

	-- Section 6.3: W is derived from the committed artifacts and the derivation
	-- travels with the run.  The pool term is recomputed from the corpus label
	-- rule rather than read out of the TSV, and the TSV is then required to
	-- agree row for row -- a hardcoded list, or a silently regenerated
	-- candidates file, both fail here.
	local function derive_w(corpus, candidate_bytes, hasher)
		local hash = hasher or raw_sha256
		if type(hash) ~= "function" then fail("no hasher was injected") end
		if type(corpus) ~= "table" or type(corpus.extreme_candidate) ~= "function" then
			fail("seed corpus module is missing")
		end
		if type(candidate_bytes) ~= "string" then fail("candidate rows are missing") end
		corpus.verify(hash)

		local rows, header_seen = {}, false
		for line in (candidate_bytes .. "\n"):gmatch("(.-)\n") do
			if line ~= "" then
				local fields = {}
				for field in (line .. "\t"):gmatch("(.-)\t") do
					fields[#fields + 1] = field
				end
				if fields[1] == "schema" and fields[2] ~= candidates_schema then
					fail("candidate artifact schema changed")
				end
				if fields[1] == "candidate_index" then header_seen = true
				elseif header_seen then rows[#rows + 1] = fields end
			end
		end
		if not header_seen then fail("candidate artifact has no row header") end
		if #rows ~= pool_candidate_count then
			fail("candidate artifact holds " .. #rows .. " rows, expected " ..
				pool_candidate_count)
		end

		local seeds, seen, duplicates = {}, {}, 0
		local function add(seed, label)
			validate_seed_text(seed, label)
			if seen[seed] then duplicates = duplicates + 1 return end
			seen[seed] = true
			seeds[#seeds + 1] = seed
		end
		for index = 1, #corpus.fixed do
			add(corpus.fixed[index], "corpus slot " .. index)
		end
		for index = 0, pool_candidate_count - 1 do
			local derived = corpus.extreme_candidate(index, hash)
			local row = rows[index + 1]
			if row[1] ~= tostring(index) or row[2] ~= "scored" then
				fail("candidate row " .. index .. " is not a scored row in index order")
			end
			if row[6] ~= derived.decimal or row[4] ~= derived.digest then
				fail("candidate row " .. index .. " disagrees with the corpus label rule")
			end
			add(derived.decimal, "pool candidate " .. index)
		end
		-- The two named endpoints of section 6.6: they arrive through the corpus
		-- slots, and a corpus edit that dropped one would otherwise pass here.
		if not seen["0"] or not seen["18446744073709551615"] then
			fail("W lost seed 0 or max-u64")
		end
		table.sort(seeds, decimal_less)

		local blob = table.concat(seeds, "\n") .. "\n"
		return {seeds = seeds, total = #seeds, digest = digest_of(blob),
			derivation = {
				schema = "grug_wp40_census_w_v1",
				corpus_fixed = #corpus.fixed,
				pool_candidates = pool_candidate_count,
				candidates_path = candidates_path,
				candidates_schema = candidates_schema,
				duplicates = duplicates,
				order = "ascending canonical unsigned-64 decimal",
			}}
	end

	-- Section 6.6.7.  The token is the W digest itself, so it states which seed
	-- set was approved and a worker can check it against its own derivation --
	-- which is what stops a direct worker call from starting a full-W slice now
	-- that the M1 list cap is gone.  A wrong token fails even below the free
	-- budget: a token that does not match means the caller is out of date.
	local function check_go_token(token, w_digest, seed_count)
		positive_integer(seed_count, "seed count")
		if type(w_digest) ~= "string" or #w_digest ~= 64 or
				w_digest:match("[^0-9a-f]") then
			fail("the W digest is not 64 hex characters")
		end
		if token ~= nil and token ~= "" then
			if type(token) ~= "string" or token ~= w_digest then
				fail("the GO token does not match this W: expected " .. w_digest)
			end
			return true
		end
		if seed_count > free_seed_budget then
			fail("a census run over " .. seed_count .. " seeds needs the explicit " ..
				"GO token; free runs are capped at " .. free_seed_budget ..
				" seeds (plan section 6.6.7).  This W's token is " .. w_digest)
		end
		return true
	end

	-- Section 6.6.3.  Worker-seconds are projected onto wall time at the stated
	-- worker count by taking the slowest shard, because the shards run
	-- concurrently: summing them would inflate the projection by the worker
	-- count, dividing a total by it would deflate an unbalanced run.
	--
	-- The estimate is rolling: a sample carries one shard's own elapsed seconds
	-- at its own latest completion, so its rate is elapsed/completed and the
	-- whole projection is re-taken every time any shard completes a seed.  One
	-- completion is an observation, not a rate.  Recorded 2026-08-16: the first
	-- full-`W` start aborted on a 71 s/seed projection taken from eight cold
	-- first seeds -- three of them 51/53/70 s against a 34-39 s steady state --
	-- and re-measuring those same three seeds solo gave 29-32 s.  What the gate
	-- had measured was the host, not the seeds.  So the cap is applied to the
	-- slowest shard that has answered at least `cost_verdict_min_completions`
	-- times, while the slowest *observed* shard is reported alongside it: an
	-- over-cap single sample is never suppressed, it is only never decisive.
	--
	-- The verdict deliberately reads the slowest eligible shard rather than
	-- waiting for the slowest observed one to become eligible.  Waiting would
	-- let one shard that stalls after its first completion mask seven that are
	-- provably over the cap, which is the same vacuous gate in a new costume.
	local cost_verdict_min_completions = 2

	-- One estimator, two domains.  The 2026-08-18 CPU gate is the same rolling
	-- projection re-based on the workers' per-seed CPU seconds, so it is the
	-- same function reading a different field of the same sample rather than a
	-- second implementation that would drift from this one's four measured
	-- pins.
	local function project_rate(samples, field, label)
		if type(samples) ~= "table" or #samples == 0 then
			fail("cost projection needs at least one completed sample")
		end
		-- Seeded below zero rather than at it, so the first sample always claims
		-- `slowest`: a fleet whose first completions all land inside one second
		-- would otherwise project a nil slowest for its callers to dereference.
		local observed_seconds, observed = -1, nil
		local decisive_seconds, decisive = -1, nil
		for index = 1, #samples do
			local sample = samples[index]
			if type(sample) ~= "table" then fail("cost sample is not a table") end
			positive_integer(sample.size, "shard size")
			positive_integer(sample.completed, "completed seeds")
			if sample.completed < 1 then fail("cost sample completed no seed") end
			if type(sample[field]) ~= "number" or sample[field] < 0 then
				fail("cost sample has no " .. label)
			end
			local shard = sample[field] / sample.completed * sample.size
			if shard > observed_seconds then observed_seconds, observed = shard, sample end
			if sample.completed >= cost_verdict_min_completions and
					shard > decisive_seconds then
				decisive_seconds, decisive = shard, sample
			end
		end
		local driver = decisive or observed
		return {seconds = decisive and decisive_seconds or observed_seconds,
			observed_seconds = observed_seconds, worker_count = worker_count,
			slowest = observed, driver = driver,
			per_seed_seconds = driver[field] / driver.completed,
			decisive = decisive ~= nil}
	end

	local function project_wall_seconds(samples)
		local projection = project_rate(samples, "elapsed", "elapsed time")
		projection.wall_seconds = projection.seconds
		projection.observed_wall_seconds = projection.observed_seconds
		projection.cap_seconds = wall_cap_seconds
		return projection
	end

	-- The CPU half of the same sample: a shard's own accumulated CPU seconds at
	-- its own latest completion (the worker's `os.clock`, reported on the same
	-- progress line as its wall figure).
	local function project_cpu_seconds(samples)
		local projection = project_rate(samples, "cpu", "CPU time")
		projection.cpu_seconds = projection.seconds
		projection.observed_cpu_seconds = projection.observed_seconds
		projection.per_seed_cpu_seconds = projection.per_seed_seconds
		return projection
	end

	-- The one place the samples above are spelled.  The worker writes this line
	-- per completed seed and the launcher reads `completed`, `wall_seconds` and
	-- -- since 2026-08-18 -- `cpu_seconds` back out of it, so the two clocks
	-- travel adjacent and a shard's rate can never be taken from the fleet's.
	-- The CPU figure is the worker's own `os.clock`, which excludes its SHA
	-- responder because that is another process; the probe that measures the
	-- budget excludes its own for the same reason, so the two are one quantity.
	local function shard_progress_line(progress)
		if type(progress) ~= "table" then fail("shard progress is malformed") end
		positive_integer(progress.first, "shard first index")
		positive_integer(progress.last, "shard last index")
		positive_integer(progress.completed, "completed seeds")
		positive_integer(progress.total, "shard seed count")
		positive_integer(progress.wall_seconds, "shard wall seconds")
		positive_integer(progress.cpu_seconds, "shard CPU seconds")
		positive_integer(progress.eta_seconds, "shard ETA seconds")
		if progress.completed < 1 or progress.completed > progress.total then
			fail("a shard progress line reports " .. progress.completed .. " of " ..
				progress.total .. " seeds")
		end
		return ("WP40 T2 census shard progress range=%04d..%04d current=%04d " ..
			"completed=%d/%d wall_seconds=%d cpu_seconds=%d eta_seconds=%d"):format(
			progress.first, progress.last,
			progress.first + progress.completed - 1, progress.completed,
			progress.total, progress.wall_seconds, progress.cpu_seconds,
			progress.eta_seconds)
	end

	-- Returns the verdict instead of a bare `true`, because "deferred" is not a
	-- pass: it is the gate reporting that no shard has answered twice yet, and a
	-- launcher that prints it shows why an over-cap observation did not abort.
	--
	-- No launcher calls this any more (section 6.5, 2026-08-18: wall time is not
	-- a kill criterion).  It stays as the estimator's pinned verdict: the replay
	-- tests drive the two measured completion timelines through it, in the wall
	-- domain they were measured in, and the CPU gate below is the same rule on
	-- the same estimator -- so a change to the deferral or slowest-shard
	-- behaviour still has to answer to those measurements.
	local function check_cost_gate(projection, cap)
		if type(projection) ~= "table" or type(projection.wall_seconds) ~= "number" then
			fail("cost projection is malformed")
		end
		local limit = cap or wall_cap_seconds
		if type(limit) ~= "number" or limit <= 0 then fail("cost cap is invalid") end
		if not projection.decisive then return "deferred" end
		if projection.wall_seconds > limit then
			fail(("projected %d s wall at %d workers exceeds the %d s cap " ..
				"(plan section 6.5)"):format(math.floor(projection.wall_seconds),
				worker_count, math.floor(limit)))
		end
		return "passed"
	end

	-- Section 6.5's intrinsic gate (2026-08-18).  The budget is a *per-seed* CPU
	-- figure because the anchor it is built from is one -- the probe's worst
	-- solo per-seed CPU times the measured contention margin -- and because a
	-- rate is the one form of this comparison no shard size enters.  The
	-- shard-length extension is reported beside it and is the same number seen
	-- from the other end: `cpu_seconds` is exactly `per_seed_cpu_seconds` times
	-- the driving shard's size.  Deferral is the wall gate's rule unchanged: two
	-- completions before a shard's rate may cast a verdict, and a single
	-- over-budget observation is reported without being able to stop the run.
	local function check_cpu_gate(projection, budget)
		if type(projection) ~= "table" or
				type(projection.per_seed_cpu_seconds) ~= "number" then
			fail("CPU projection is malformed")
		end
		if type(budget) ~= "number" or budget <= 0 then
			fail("CPU budget is invalid")
		end
		if not projection.decisive then return "deferred" end
		if projection.per_seed_cpu_seconds > budget then
			fail(("projected %.2f s CPU per seed (%d s per shard over %d seeds) " ..
				"exceeds the %.2f s CPU budget (plan section 6.5)"):format(
				projection.per_seed_cpu_seconds, math.floor(projection.cpu_seconds),
				projection.driver.size, budget))
		end
		return "passed"
	end

	-- The budget itself: measured, never restated.  `anchor` is the worst solo
	-- per-seed CPU of a census worker seed and `margin` the worst CPU inflation
	-- the same seeds showed under full synthetic host load, both from
	-- t2_census_probe_contention.lua.  A margin below one would be a probe that
	-- measured the loaded pass as *cheaper* than the solo one, which is a broken
	-- measurement rather than a tight budget.
	local function cpu_budget_seconds(anchor, margin)
		if type(anchor) ~= "number" or anchor <= 0 then
			fail("the CPU anchor must be a positive number of seconds")
		end
		if type(margin) ~= "number" or margin < 1 then
			fail("the contention margin must be at least 1")
		end
		return anchor * margin
	end

	-- Section 6.5's liveness gate (2026-08-18), the busy-loop hang the retired
	-- wall cap used to catch by accident.  The fleet consuming CPU while no seed
	-- closes is the pathology; a fleet merely starved by user work -- which is
	-- what idle scheduling makes normal, not exceptional -- consumes nothing and
	-- is never accused of it.  The honest residual is recorded in the plan: a
	-- worker blocked forever while consuming no CPU trips nothing here.
	local function check_liveness_gate(state)
		if type(state) ~= "table" then fail("liveness state is malformed") end
		if type(state.consumed) ~= "number" or state.consumed < 0 then
			fail("liveness state has no consumed CPU seconds")
		end
		positive_integer(state.completed_since, "completions since the last seed")
		if type(state.allowance) ~= "number" or state.allowance <= 0 then
			fail("the liveness CPU allowance is invalid")
		end
		if state.completed_since > 0 then return "progressing" end
		if state.consumed > state.allowance then
			fail(("the fleet consumed %d s CPU since its last completed seed, over " ..
				"the %d s allowance (plan section 6.5)"):format(
				math.floor(state.consumed), math.floor(state.allowance)))
		end
		return "quiet"
	end

	local function iso_date(value, label)
		if type(value) ~= "string" or not value:match("^%d%d%d%d%-%d%d%-%d%d$") then
			fail(label .. " is not an ISO date: " .. tostring(value))
		end
		return value
	end

	-- Parsed, never sourced.  The file is shell-sourceable by contract -- the
	-- operator reads it and a shell could take it verbatim -- but a launcher
	-- that sourced it would execute whatever a stale editor buffer left in it,
	-- and every key here has a declared shape a strict reader can refuse.  An
	-- undeclared key is refused too: a misspelled one would otherwise read as a
	-- missing measurement rather than as the typo it is.
	local function read_cpu_gate_conf(text, head_date)
		if type(text) ~= "string" then fail("the CPU gate conf is not readable") end
		local declared = {}
		for index = 1, #cpu_gate_conf_keys do declared[cpu_gate_conf_keys[index]] = true end
		local values, line_number = {}, 0
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			line_number = line_number + 1
			if not line:match("^%s*$") and not line:match("^%s*#") then
				local key, value = line:match("^([A-Z_]+)=(%S+)%s*$")
				if not key then
					fail("CPU gate conf line " .. line_number ..
						" is not a KEY=VALUE assignment: " .. line)
				end
				if not declared[key] then
					fail("CPU gate conf line " .. line_number .. " declares the " ..
						"undeclared key " .. key)
				end
				if values[key] then
					fail("CPU gate conf declares " .. key .. " twice")
				end
				values[key] = value
			end
		end
		for index = 1, #cpu_gate_conf_keys do
			if not values[cpu_gate_conf_keys[index]] then
				fail("the CPU gate conf declares no " .. cpu_gate_conf_keys[index] ..
					"; re-run tools/wp40/run_t2_census_probe.sh (plan section 6.5)")
			end
		end
		local anchor = tonumber(values.ANCHOR_CPU_SECONDS)
		local margin = tonumber(values.CONTENTION_MARGIN)
		local allowance = tonumber(values.LIVENESS_X_CPU_SECONDS)
		if not anchor or not margin or not allowance then
			fail("the CPU gate conf holds a value that is not a number")
		end
		if allowance <= 0 then
			fail("LIVENESS_X_CPU_SECONDS must be a positive number of seconds")
		end
		local probe_date = iso_date(values.PROBE_DATE, "PROBE_DATE")
		if head_date ~= nil then
			iso_date(head_date, "the HEAD commit date")
			if probe_date < head_date then
				fail("the CPU gate conf was measured on " .. probe_date ..
					", older than the HEAD commit of " .. head_date ..
					"; re-run tools/wp40/run_t2_census_probe.sh (plan section 6.5)")
			end
		end
		return {anchor = anchor, margin = margin, allowance = allowance,
			probe_date = probe_date, budget = cpu_budget_seconds(anchor, margin)}
	end

	local function split_line(line)
		local fields = {}
		for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
		return fields
	end

	-- ------------------------------------------------------------------
	-- The Scan-4 membership (contracts 9.2, RULED 2026-08-19: branch A).
	-- The consumed membership is the committed v2 seed-set artifact by
	-- digest plus the v2 manifest's seven detached-shoulder admission seeds
	-- -- re-admitting exactly the three departed D2 seeds.  Every count
	-- below is a measured fact of the ruling and is asserted, not assumed:
	-- 3,058 seed rows, 7 admissions, 3 newcomers, union 3,061.  The two
	-- fixture digests are pinned here, and this file is itself a module
	-- path, so a membership edit moves the module digest and can never
	-- silently change which seeds a shard ran Scan-4 on.
	-- ------------------------------------------------------------------
	local scan4_membership_source = {
		seed_set_path = "tools/wp40/fixtures/t2_census/census-scan4-seed-set-v2.tsv",
		seed_set_digest =
			"a7f4ab910ddc6a1ace360a3a26e0adfaf14b9f5b74c50bb3b9b93ebf6231a79d",
		manifest_path = "tools/wp40/fixtures/t2_census/census-manifest-v2.tsv",
		manifest_digest =
			"27aa7e7b8c09621e0acb8181bb7cb2ced73b4dcbd8e025e34673be035b73e7f2",
		seed_rows = 3058, admissions = 7, newcomers = 3, union = 3061,
		ruling = "contracts 9.2 ruled 2026-08-19: branch A -- " ..
			"detached_shoulder_admission enters the flag vocabulary and the " ..
			"union returns to 3,061",
	}

	local function read_scan4_membership(seed_set_bytes, manifest_bytes)
		if type(seed_set_bytes) ~= "string" or type(manifest_bytes) ~= "string" then
			fail("the Scan-4 membership inputs are missing")
		end
		if digest_of(seed_set_bytes) ~= scan4_membership_source.seed_set_digest then
			fail("the Scan-4 seed-set artifact does not match its pinned digest " ..
				scan4_membership_source.seed_set_digest .. " (contracts 9.2)")
		end
		if digest_of(manifest_bytes) ~= scan4_membership_source.manifest_digest then
			fail("the v2 census manifest does not match its pinned digest " ..
				scan4_membership_source.manifest_digest .. " (contracts 9.2)")
		end
		local members, sources = {}, {}
		local seed_rows = 0
		for line in (seed_set_bytes):gmatch("([^\n]*)\n") do
			local fields = split_line(line)
			if fields[1] == "seed" then
				local seed = validate_seed_text(fields[2], "Scan-4 member seed")
				if members[seed] then fail("Scan-4 member seed " .. seed .. " repeats") end
				members[seed], sources[seed] = true, "seed_set"
				seed_rows = seed_rows + 1
			end
		end
		if seed_rows ~= scan4_membership_source.seed_rows then
			fail("the v2 seed-set artifact holds " .. seed_rows ..
				" seed rows, the ruling consumed " ..
				scan4_membership_source.seed_rows)
		end
		local admissions, newcomers = 0, 0
		for line in (manifest_bytes):gmatch("([^\n]*)\n") do
			local fields = split_line(line)
			if fields[1] == "detached_shoulder_admission" then
				local seed = fields[2] and fields[2]:match("seed=(%d+)")
				if not seed then
					fail("a detached_shoulder_admission manifest line names no seed")
				end
				validate_seed_text(seed, "admission seed")
				admissions = admissions + 1
				if not members[seed] then
					members[seed], sources[seed] = true, "admission"
					newcomers = newcomers + 1
				end
			end
		end
		if admissions ~= scan4_membership_source.admissions then
			fail("the v2 manifest lists " .. admissions ..
				" admission seeds, the ruling consumed " ..
				scan4_membership_source.admissions)
		end
		if newcomers ~= scan4_membership_source.newcomers then
			fail("the admission re-admitted " .. newcomers ..
				" seeds, the ruling names " .. scan4_membership_source.newcomers)
		end
		local union = seed_rows + newcomers
		if union ~= scan4_membership_source.union then
			fail("the consumed Scan-4 union is " .. union .. ", the ruling says " ..
				scan4_membership_source.union)
		end
		return {members = members, sources = sources, union = union,
			seed_set_digest = scan4_membership_source.seed_set_digest,
			manifest_digest = scan4_membership_source.manifest_digest}
	end

	local function split_lines(text)
		if type(text) ~= "string" then fail("shard text is not a string") end
		local lines = {}
		local position = 1
		while position <= #text do
			local newline = text:find("\n", position, true)
			if not newline then
				fail("shard text ends without a newline")
			end
			lines[#lines + 1] = text:sub(position, newline - 1)
			position = newline + 1
		end
		return lines
	end

	-- The shard header.  Range mode adds these lines to the M1 body; `--kat`
	-- and explicit seed lists keep the frozen M1 bytes exactly, which is what
	-- lets the pinned KAT digest stay the proof that the hasher change was
	-- digest-neutral.
	local shard_header_tags = {"schema", "vocabulary", "shard_schema",
		"shard_range", "shard_seeds", "w_digest", "w_total", "census_commit",
		"census_tree", "module_digest", "interpreter_id", "interpreter_path",
		"interpreter_version"}

	local function shard_header_lines(header)
		if type(header) ~= "table" then fail("shard header is not a table") end
		local lines = {}
		for index = 1, #shard_header_tags do
			local tag = shard_header_tags[index]
			local value = header[tag]
			if tag == "shard_range" then
				positive_integer(header.first, "shard first index")
				positive_integer(header.last, "shard last index")
				value = header.first .. "\t" .. header.last
			end
			if type(value) ~= "string" and type(value) ~= "number" then
				fail("shard header field " .. tag .. " is missing")
			end
			value = tostring(value)
			if value == "" or value:find("\n", 1, true) then
				fail("shard header field " .. tag .. " is not a single value")
			end
			lines[index] = tag .. "\t" .. value
		end
		return lines
	end

	local function parse_header(lines, expected)
		local header = {}
		for index = 1, #shard_header_tags do
			local line = lines[index]
			if type(line) ~= "string" then fail("shard header is truncated") end
			local fields = split_line(line)
			local tag = shard_header_tags[index]
			if fields[1] ~= tag then
				fail("shard header line " .. index .. " is " .. tostring(fields[1]) ..
					", expected " .. tag)
			end
			if tag == "shard_range" then
				if #fields ~= 3 then fail("shard_range needs two indices") end
				header.first = tonumber(fields[2])
				header.last = tonumber(fields[3])
				if not header.first or not header.last then
					fail("shard_range indices are not numbers")
				end
				positive_integer(header.first, "shard first index")
				positive_integer(header.last, "shard last index")
			else
				if #fields ~= 2 then fail("shard header field " .. tag .. " is malformed") end
				header[tag] = fields[2]
			end
		end
		if header.schema ~= schema then fail("shard schema is " .. tostring(header.schema)) end
		if header.shard_schema ~= shard_schema then
			fail("shard framing schema is " .. tostring(header.shard_schema))
		end
		if header.vocabulary ~= vocabulary_path then
			fail("shard vocabulary authority is " .. tostring(header.vocabulary))
		end
		if expected then
			if expected.first and header.first ~= expected.first or
					expected.last and header.last ~= expected.last then
				fail("shard range is not the range this shard was launched for")
			end
			if expected.w_digest and header.w_digest ~= expected.w_digest then
				fail("shard was produced for a different W")
			end
			if expected.census_commit and header.census_commit ~= expected.census_commit then
				fail("shard was produced at commit " .. tostring(header.census_commit))
			end
			if expected.module_digest and header.module_digest ~= expected.module_digest then
				fail("shard was produced by different module bytes: " ..
					tostring(header.module_digest))
			end
		end
		-- This field is a bounded row count, not one of the uint64 seed texts.
		-- Give the numeric conversion a count-only name so the T0/T1 source
		-- audit can continue to reject every full-identity numeric conversion.
		local count_text = header.shard_seeds
		local shard_count = tonumber(count_text)
		if not shard_count or shard_count ~= header.last - header.first + 1 then
			fail("shard_seeds disagrees with shard_range")
		end
		header.shard_seeds = shard_count
		return header
	end

	-- Returns the offset after the block and the block itself: artifact 4 is
	-- the discharge list and the merge has to prove all eight shards carry the
	-- same one, so the rows travel with the verification rather than being
	-- split a second time.
	local function validate_prefilter(lines, offset)
		local rows = {}
		for index = 1, prefilter_edge_count do
			local line = lines[offset + index]
			if type(line) ~= "string" then fail("prefilter block is truncated") end
			local fields = split_line(line)
			if fields[1] ~= "prefilter" or #fields ~= 4 then
				fail("prefilter row " .. index .. " is malformed")
			end
			if not class_sets.prefilter_status[fields[3]] then
				fail("prefilter row " .. index .. " has status " .. tostring(fields[3]))
			end
			if fields[2] == "" or fields[4] == "" then
				fail("prefilter row " .. index .. " has an empty edge or reason")
			end
			rows[index] = {edge_id = fields[2], status = fields[3],
				reason = fields[4], line = line}
		end
		return offset + prefilter_edge_count, rows
	end

	-- One seed record, checked against the contract: every declared site
	-- present exactly once per its roster count, every row the declared width,
	-- every class string drawn from the declared vocabulary, every row carrying
	-- the block's own seed.  Returns the index after `seed_end`.
	-- `on_row` lets a caller consume the rows this pass already split, which is
	-- what keeps the M5 merge to one parse of a 13 MB shard instead of
	-- verifying it and then re-splitting every line to aggregate it.  It is
	-- strictly optional and is called only for rows the checks below accepted.
	local function validate_record(lines, offset, expected_seed, on_row)
		local open_line = lines[offset + 1]
		if type(open_line) ~= "string" then fail("seed record is missing") end
		local open_fields = split_line(open_line)
		if open_fields[1] ~= "seed_begin" or #open_fields ~= 2 then
			fail("seed record does not open with seed_begin")
		end
		local seed = validate_seed_text(open_fields[2], "seed record seed")
		if expected_seed and seed ~= expected_seed then
			fail("seed record holds seed " .. seed .. ", expected " .. expected_seed)
		end
		local counts = {}
		local membership_kind
		local index = offset + 2
		while true do
			local line = lines[index]
			if type(line) ~= "string" then fail("seed record " .. seed .. " is truncated") end
			local fields = split_line(line)
			local tag = fields[1]
			if tag == "seed_end" then
				if #fields ~= 2 or fields[2] ~= seed then
					fail("seed record " .. seed .. " closes on a different seed")
				end
				break
			end
			local layout = record_row_by_tag[tag]
			if not layout then
				fail("seed record " .. seed .. " holds an unknown row tag " .. tostring(tag))
			end
			if #fields ~= layout.fields then
				fail(tag .. " row in seed " .. seed .. " has " .. #fields ..
					" fields, expected " .. layout.fields)
			end
			if fields[2] ~= seed then
				fail(tag .. " row in seed " .. seed .. " carries seed " .. tostring(fields[2]))
			end
			if layout.class_set and
					not class_sets[layout.class_set][fields[layout.class_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared class " ..
					tostring(fields[layout.class_field]))
			end
			if layout.extra_set and
					not class_sets[layout.extra_set][fields[layout.extra_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared kind " ..
					tostring(fields[layout.extra_field]))
			end
			if layout.extra2_set and
					not class_sets[layout.extra2_set][fields[layout.extra2_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared kind " ..
					tostring(fields[layout.extra2_field]))
			end
			counts[tag] = (counts[tag] or 0) + 1
			if tag == "scan4_membership" then membership_kind = fields[3] end
			if on_row then on_row(tag, fields, seed) end
			index = index + 1
		end
		-- The two v4 record shapes, mutually exclusive: a stage-rejected seed
		-- emits exactly one stage_reject row and nothing else -- it has no
		-- stage to project any roster from -- and a full record must not
		-- carry one, so a partial roster can never hide behind a reject row.
		if counts.stage_reject then
			if counts.stage_reject ~= 1 then
				fail("seed record " .. seed .. " holds " .. counts.stage_reject ..
					" stage_reject rows; a stage-rejected seed emits exactly one")
			end
			for tag in pairs(counts) do
				if tag ~= "stage_reject" then
					fail("seed record " .. seed .. " mixes a stage_reject row with " ..
						tag .. " rows")
				end
			end
		else
			for row_index = 1, #record_rows do
				local layout = record_rows[row_index]
				if layout.count and (counts[layout.tag] or 0) ~= layout.count then
					fail("seed record " .. seed .. " holds " .. (counts[layout.tag] or 0) ..
						" " .. layout.tag .. " rows, expected " .. layout.count)
				end
			end
			-- The member-conditional Scan-4 block (contracts 9.2/9.6): a
			-- member record carries all 38 face rows and exactly one whole
			-- row; a non-member record carries none of the four Scan-4 row
			-- kinds beyond its membership row.  This is what the merge's
			-- coverage re-verification leans on, so it is grammar here and
			-- re-checked there.
			if membership_kind == "member" then
				if (counts.scan4_face or 0) ~= 38 then
					fail("member seed record " .. seed .. " holds " ..
						(counts.scan4_face or 0) .. " scan4_face rows, expected 38")
				end
				if (counts.scan4_whole or 0) ~= 1 then
					fail("member seed record " .. seed .. " holds " ..
						(counts.scan4_whole or 0) .. " scan4_whole rows, expected 1")
				end
			else
				for _, tag in ipairs({"scan4_face", "scan4_whole",
						"scan4_whole_interval", "scan4_fragment"}) do
					if counts[tag] then
						fail("non-member seed record " .. seed .. " holds " ..
							counts[tag] .. " " .. tag .. " rows")
					end
				end
			end
		end
		return index, seed, counts
	end

	-- Section 6.6.2, run against a shard that is still being written: return
	-- nil when no record has closed yet, and fail hard on anything the contract
	-- forbids.  "Not ready yet" and "broken" must never look alike here.
	--
	-- v4: a stage-rejected seed has no stage to derive the seed-independent
	-- prefilter from, so stage_reject records may precede the prefilter block
	-- and the first closed record can be one of them.  A full record before
	-- the block stays a refusal.
	local function validate_first_record(text, expected)
		local lines = split_lines(text)
		if #lines < #shard_header_tags then return nil end
		local header = parse_header(lines, expected)
		local offset = #shard_header_tags
		local closed = false
		for index = offset + 1, #lines do
			if lines[index]:sub(1, 9) == "seed_end\t" then closed = true break end
		end
		if not closed then return nil end
		local prefilter_seen = false
		if type(lines[offset + 1]) == "string" and
				lines[offset + 1]:sub(1, 10) == "prefilter\t" then
			offset = validate_prefilter(lines, offset)
			prefilter_seen = true
		end
		local expected_seed = expected and expected.seeds and expected.seeds[1]
		local _, seed, counts = validate_record(lines, offset, expected_seed)
		if not counts.stage_reject and not prefilter_seen then
			fail("shard holds a full seed record before its prefilter block")
		end
		return {seed = seed, header = header, counts = counts,
			stage_reject = counts.stage_reject ~= nil}
	end

	-- The digest line and the record block, which the shard framing and the
	-- free-run framing share exactly; only the header above them differs.
	local function split_verified_body(text, label)
		if type(text) ~= "string" then fail(label .. " bytes are missing") end
		if text == "" then
			fail(label .. " file is empty -- a claimed but unfinished worker output")
		end
		local lines = split_lines(text)
		local last_line = lines[#lines]
		local digest = last_line and last_line:match("^digest\tsha256=([0-9a-f]+)$")
		if not digest or #digest ~= 64 then
			fail(label .. " file has no trailing digest line -- unfinished or corrupt")
		end
		local recomputed = digest_of(text:sub(1, #text - (#last_line + 1)))
		if recomputed ~= digest then
			fail(label .. " digest is " .. digest .. ", recomputed " .. recomputed)
		end
		return lines, digest
	end

	-- The v4 record stream: zero or more stage_reject records may precede the
	-- prefilter block -- a seed that dies in stage build has no prefilter to
	-- attest -- but the block appears exactly once and before the first full
	-- record.  An input with no full record at all is refused: nothing in it
	-- can attest the seed-independent prefilter that artifact 4 commits, so
	-- the operator re-scopes by hand instead of the merge inventing a block.
	-- (At the witnessed ~1/285 occupancy an all-reject input cannot occur;
	-- the refusal exists so the grammar is total rather than hopeful.)
	local function read_body(lines, offset, expected_seeds, on_row, label)
		local seeds, totals = {}, {}
		local prefilter, full_seen
		while offset < #lines - 1 do
			local line = lines[offset + 1]
			if type(line) ~= "string" then fail(label .. " is truncated") end
			if line:sub(1, 10) == "prefilter\t" then
				if prefilter then fail(label .. " holds a second prefilter block") end
				offset, prefilter = validate_prefilter(lines, offset)
			else
				local expected_seed = expected_seeds and expected_seeds[#seeds + 1]
				local next_offset, seed, counts =
					validate_record(lines, offset, expected_seed, on_row)
				if not counts.stage_reject then
					if not prefilter then
						fail(label .. " holds a full seed record before its prefilter block")
					end
					full_seen = true
				end
				seeds[#seeds + 1] = seed
				for tag, count in pairs(counts) do totals[tag] = (totals[tag] or 0) + count end
				offset = next_offset
			end
		end
		if offset ~= #lines - 1 then
			fail(label .. " holds trailing text after its last record")
		end
		-- The full-record check comes first and is the one that carries the
		-- refusal's meaning: a prefilter block that no full record of this
		-- input attests -- for instance one copied from a sibling shard into
		-- an all-reject body -- must not count as attestation.
		if not full_seen then
			fail(label .. " holds no full seed record, so nothing attests its " ..
				"seed-independent prefilter block")
		end
		if not prefilter then
			fail(label .. " holds no prefilter block")
		end
		return seeds, totals, prefilter
	end

	-- Kept separate from read_records and applied after the header count, so a
	-- shard that lost a record still fails on its own header first: that is the
	-- message the resume gate's negative proof names, and the more specific
	-- one, since a header disagreeing with its body is a corrupt file rather
	-- than a mismatched request.
	local function check_expected_seeds(seeds, expected_seeds, label)
		if expected_seeds and #expected_seeds ~= #seeds then
			fail(label .. " covers " .. #seeds .. " of " .. #expected_seeds ..
				" expected seeds")
		end
	end

	-- Section 6.6.4.  Every failure below is a loud abort, including the empty
	-- claim file a crashed worker leaves behind: a zero-length or digest-less
	-- path is unparseable, never an empty shard.
	local function verify_shard(text, expected, on_row)
		local lines, digest = split_verified_body(text, "shard")
		local header = parse_header(lines, expected)
		local seeds, totals, prefilter = read_body(lines, #shard_header_tags,
			expected and expected.seeds, on_row, "shard")
		if #seeds ~= header.shard_seeds then
			fail("shard holds " .. #seeds .. " seed records, its header declares " ..
				header.shard_seeds)
		end
		check_expected_seeds(seeds, expected and expected.seeds, "shard")
		return {header = header, seeds = seeds, totals = totals, digest = digest,
			prefilter = prefilter}
	end

	-- A free run (`--kat` or an explicit seed list) keeps the frozen M1
	-- preamble and adds no shard header, so verify_shard cannot read one --
	-- and the M5 merge KAT has nothing else to consume.  Everything below the
	-- preamble is the same grammar and goes through the same checks; what is
	-- deliberately absent is the provenance a shard header carries, so a free
	-- record set can never be merged as if it were a slice of `W`.
	local function verify_free_output(text, expected, on_row)
		local lines, digest = split_verified_body(text, "census record set")
		if lines[1] ~= "schema\t" .. schema then
			fail("census record set schema is " .. tostring(lines[1]))
		end
		if lines[2] ~= "vocabulary\t" .. vocabulary_path then
			fail("census record set vocabulary authority is " .. tostring(lines[2]))
		end
		if lines[3] and lines[3]:sub(1, 13) == "shard_schema\t" then
			fail("a shard-framed file must be verified as a shard, not as a free run")
		end
		local seeds, totals, prefilter = read_body(lines, 2,
			expected and expected.seeds, on_row, "census record set")
		if #seeds == 0 then fail("census record set holds no seed record") end
		check_expected_seeds(seeds, expected and expected.seeds,
			"census record set")
		return {seeds = seeds, totals = totals, digest = digest,
			prefilter = prefilter}
	end

	-- The section-11.5-C appendix acceptance pins (ruled 2026-08-20,
	-- completed by the 11.9 ruling, re-ruled by 11.10 on the complete
	-- distribution), with their measurement provenance.  The window (pin
	-- lineage W 8 -> 11 -> 12): over all 95 preserved corridor violations
	-- of the step-2/2b sweeps, every repeat sits within 6 ring stations
	-- of one part join, both occurrences, no pair straddling two joins
	-- (the 11.5 investigation, measurement 2 -- an 8.5% dump sample);
	-- ruled one wider at W = 8, then refuted by the section-11.8 union
	-- sweep (observed maximum 11 -- in fact a one-witness
	-- generalization, refuted in turn by the fourth-attempt acceptance
	-- sweep).  The complete distribution now exists
	-- (b-join-distances.tsv of the w11 stop artifacts: all 60 family-B
	-- seeds, 93 repeated stations, d=1 x14, 2 x10, 8 x7, 9 x9, 10 x25,
	-- 11 x23, 12 x5, nothing beyond 12 -- the silverleaf touch family
	-- 1138-1140:-2232 against its join anchor jittering +-1 over
	-- 1126/1127/1128:-2233), and the 11.10 ruling pins W := 12 at the
	-- complete-population maximum exactly -- the first W pin whose
	-- provenance is a complete population; no margin, anything farther
	-- stays a named loud failure.  The acceptance predicate is 11.9's join-local,
	-- LOCALLY NON-CROSSING self-touch: at a repeated station the two
	-- passes must not interleave in the cyclic order of the four incident
	-- ring edges (integer-only; a crossing fails by name).  The zero-width
	-- condition -- ratified by 11.9 as *no cardinal 4-neighbour strictly
	-- interior by winding* -- now records the touch FORM instead of gating
	-- it: zero width is the filament appendix, strict interior beside the
	-- touch is the pinch (the 19 measured interior-hugging one-station
	-- dips of 11.8 family B), and the row detail carries both counts.
	-- Zero-width provenance: the 92 probed corridor stations of the 11.5
	-- investigation are straight filaments (both laterals strictly
	-- outside); the corridor mouth at an L-turn -- measured 2026-08-20 on
	-- W-112's dawnmere corridor during the section-11 package's KAT
	-- measurement, station -634:-2918, classes E=0/W=-1/N=0/S=0 -- has
	-- boundary neighbours on both axes and still no interior beside it, so
	-- the lateral-pair phrasing of the investigation was the probe's
	-- sufficient check on its straight sample, not the ruled predicate.
	-- partition.lua owns the running copy; the worker refuses to run when
	-- the two disagree, the stage-reject-class precedent.
	authority.face_appendix_window = 12

	authority.schema = schema
	authority.shard_schema = shard_schema
	authority.vocabulary_path = vocabulary_path
	authority.candidates_path = candidates_path
	authority.worker_count = worker_count
	authority.wall_cap_seconds = wall_cap_seconds
	authority.cost_verdict_min_completions = cost_verdict_min_completions
	authority.free_seed_budget = free_seed_budget
	authority.pool_candidate_count = pool_candidate_count
	authority.classes = classes
	authority.wing_exclusion_causes = wing_exclusion_causes
	authority.exclusion_vocabulary = exclusion_vocabulary
	authority.class_vocabulary_kind = class_vocabulary_kind
	authority.class_verdict = class_verdict
	authority.refuted_universal = refuted_universal
	authority.branch_notes = branch_notes
	authority.derived_branches = derived_branches
	authority.unmeasured_branches = unmeasured_branches
	authority.extremal_families = extremal_families
	authority.extremal_site_total = extremal_site_total
	authority.derived_scalars = derived_scalars
	authority.flag_rules = flag_rules
	authority.scan4_membership_source = scan4_membership_source
	authority.read_scan4_membership = read_scan4_membership
	authority.branch_universe = branch_universe
	authority.record_rows = record_rows
	authority.record_row_by_tag = record_row_by_tag
	authority.field = field
	authority.site_of = site_of
	authority.prefilter_edge_count = prefilter_edge_count
	authority.module_paths = module_paths
	authority.module_digest = module_digest
	authority.launcher_paths = launcher_paths
	authority.shard_directory = shard_directory
	authority.shard_header_tags = shard_header_tags
	authority.shard_header_lines = shard_header_lines
	authority.census_shard_path = census_shard_path
	authority.validate_census_shard_path = validate_census_shard_path
	authority.validate_free_output_path = validate_free_output_path
	authority.assert_disjoint_from_pool = assert_disjoint_from_pool
	authority.shard_ranges = shard_ranges
	authority.validate_shard_range = validate_shard_range
	authority.decimal_less = decimal_less
	authority.validate_seed_text = validate_seed_text
	authority.derive_w = derive_w
	authority.check_go_token = check_go_token
	authority.project_wall_seconds = project_wall_seconds
	authority.check_cost_gate = check_cost_gate
	authority.project_cpu_seconds = project_cpu_seconds
	authority.check_cpu_gate = check_cpu_gate
	authority.cpu_budget_seconds = cpu_budget_seconds
	authority.check_liveness_gate = check_liveness_gate
	authority.read_cpu_gate_conf = read_cpu_gate_conf
	authority.cpu_gate_conf_path = cpu_gate_conf_path
	authority.cpu_gate_conf_keys = cpu_gate_conf_keys
	authority.shard_progress_line = shard_progress_line
	authority.validate_first_record = validate_first_record
	authority.verify_shard = verify_shard
	authority.verify_free_output = verify_free_output
	authority.split_line = split_line
	authority.digest_of = digest_of
	return authority
end
