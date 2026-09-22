extends "res://tests/social_relations.gd"

func run() -> void:
	if not setup(): quit(1); return
	save_fixture(second_night(), "preparation")
	for pair in [["social_preview_respected", "respected"], ["social_preview_disliked", "disliked"]]:
		run_def = catalog.get_definition("runs",pair[0]); save_fixture(second_night(),pair[1])
	run_def = catalog.get_definition("runs","social_preview_hostile")
	var found := false
	for seed_value in 40:
		var s := second_night(seed_value)
		if s._day.state.social.pending.get("kind", "") == "closure": save_fixture(s,"closure"); found = true; break
	check(found,"closure fixture through configured history")
	run_def = catalog.get_definition("runs","social_preview_connected")
	found = false
	for seed_value in 40:
		var s := second_night(seed_value)
		var p: Dictionary = s._day.state.social.pending
		if p.get("kind", "") != "supply": continue
		var disputed: Array = p.offers.filter(func(row: Dictionary) -> bool: return row.disputed)
		if disputed.is_empty(): continue
		save_fixture(s,"supply")
		check(s.social_command("select_supply",disputed[0].id).ok,"choose disputed fixture")
		act(s,"open_shop"); driver.drain(s)
		var v := s._counter.customers.active(s._day.state)
		check(s.social_command("check_supply",v.visit_id).ok,"investigate disputed before paying")
		check(s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok,"buy disputed for consequence")
		finish_night(s); driver.drain(s); act(s,"open_shop"); driver.drain(s); finish_night(s); driver.drain(s)
		check(s._day.state.social.pending.get("kind", "") == "claim","owner comes two nights later")
		save_fixture(s,"claim"); found = true; break
	check(found,"supply and claim fixtures")
	print("SOCIAL FIXTURES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func save_fixture(s: RunSession, stage: String) -> void:
	verify(s,stage)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/social-relations")
	var file := FileAccess.open("res://.godot/qa/social-relations/" + stage + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,27)))
