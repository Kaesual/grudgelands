-- Stage-S1 activation gate for the E0 scalar pool.
--
-- The extreme selector consumes stage S1 only, so this gate pins the stage-S1
-- authority digest published by tools/wp40/t2_s1_authority.lua: the S1 module
-- bytes, the arithmetic surface S1 reads, and the canonical checksum of the S1
-- Source projection.
--
-- What this gate deliberately does NOT pin, and why: source/catalog.lua bytes,
-- geometry/partition.lua bytes, and the boundary-displacement policy checksum.
-- None of the three can move an S1 scalar identity or value, yet pinning them
-- invalidated a measured 4096-seed pool on every later-stage geometry
-- correction -- which is why the pool has been unreachable since R16.  The S1
-- projection below is bit-identical from the T2b seed-zero geometry freeze
-- (db62f43) through R19, so a pool measured under this gate survives R16..R19
-- and every future correction that leaves S1 alone.
--
-- The immutable worker recomputes both digests from its own captured snapshot
-- and from the live S1 projection before it publishes any shard.
return {
	status = "enabled_on_stage_s1_authority",
	s1_authority_schema = "grug_wp40_s1_authority_v1",
	s1_authority_sha256 =
		"10a790a6436a740efc83e98afe3c374ac4b3520bb425de3d2bd0ac76622db37c",
	s1_source_projection_schema = "grug_wp40_s1_boundary_projection_v1",
	s1_source_projection_sha256 =
		"83b1b16a8afd11af654b5dd3e1d9921006848a0903e7b0c01ab39b27edddd652",
}
