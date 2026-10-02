-- The Shipwright (docs/design/boats.md section 2): one per capital, at the
-- shared stable beside the Riding Trainer. He sells the two boat tiers in the
-- Riding Trainer's dialogue format and nothing else; the dialogue, its
-- own-faction check and the purchase are trainer.lua's.
grug_mounts.SERVICES.shipwright = {title = "Shipwright",
	subtitle = "Boats are water mounts — summon one while in water",
	tiers = grug_mounts.BOAT_TIERS}

-- The mapgen publishes the socket (role `shipwright`); until it does, no
-- Shipwright stands anywhere and nothing fails.
grug_mobs.register_start_socket_role("shipwright", function(socket, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)
