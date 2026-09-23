extends "res://tests/tiered_appraisal.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	var library := SaveLibrary.new("res://.godot/qa/precision-storage/library-%d.json" % Time.get_ticks_usec())
	library.register_catalog("res://data/tiered_manifest.json",catalog)
	check(library.write_entry("manual/1",s._day.state,run_def,32,catalog),"real v32 disk publication "+library.error_message)
	var decoded := library.read_entry("manual/1")
	check(not decoded.is_empty() and decoded.catalog.content_version == 32,"real disk read matches v32 manifest")
	if not decoded.is_empty(): check(GhostSaveCodec.same(decoded.state.to_read_model(),s.read_state()),"real disk replay is exact")
	var old_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/wealthy/appraised.json"))
	var old := library.decode_entry({"format":SaveLibrary.FORMAT,"saved_at":"legacy fixture","payload":old_data},true)
	check(not old.is_empty() and old.catalog.content_version == 31,"v31 appraisal record loads with original catalog")
	if not old.is_empty():
		check(library.adopt(old,s),"switch from v32 to old save")
		check(not TieredAppraisal.active(s._day.state) and not s._day.state.shop_growth.has("precision"),"legacy gets no facilities or charges")
		for v in s._day.state.visits: check(not v.item.goods.has("precision"),"legacy goods receive no new rolls")
		check(GhostSaveCodec.same(s.read_state().shop_growth.luxury,old_data.shop_growth.luxury),"legacy appraisal and quote facts are unchanged")
		s.new_run()
		check(s.content_version == 32 and s.definition.id == "precision_ten","new game returns to v32 after legacy load")
	# Upgrade inheritance: a real fan remains accessible at the third bench.
	var unit := unit_visit("customer_wealthy_silk","item_luxury_embroidery","sound"); equip(unit)
	var v: CustomerVisit = unit._day.state.visits[0]
	v.item.definition_id = GoodsExpertise.FAN; v.item.goods = {"fan_condition":"intact"}
	check(FanConditionService.desk_reason(unit._day,v.item.instance_id).is_empty(),"fan still opens with third bench and shared tools")
	check(unit.fan_command("condition",v.item.instance_id).ok,"fan basic inspection still works at third bench")
	print("PRECISION STORAGE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
