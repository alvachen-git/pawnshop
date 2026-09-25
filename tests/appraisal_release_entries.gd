extends SceneTree

func _initialize() -> void:
	var cases := {
		"start": "gramophone_release",
		"start_gramophone_v46": "gramophone_release",
		"start_pawn_v45": "pawn_interest_unified",
		"start_lu_trade_v44": "lu_trade_unified",
		"start_camera_v43": "camera_unified",
		"start_gramophone_v44": "gramophone_unified",
		"start_porcelain_v42": "porcelain_release",
		"start_first_debt_recovery_v41": "first_debt_recovery_release",
		"start_porcelain_v41": "porcelain_unified",
		"start_bangle_v40": "bangle_unified",
		"start_bangle_v39": "bangle_market_ten",
		"start_first_debt_v39": "first_debt_unified",
		"start_pearl_v38": "pearl_market_ten",
		"start_named_wealthy_v37": "named_wealthy_ten",
		"start_mirror_dream_call_v29": "mirror_dream_call_ten",
		"start_social_relations_v27": "social_relations_ten",
		"start_fan_condition_v29": "fan_condition_ten",
		"start_v27": "aqi_reunion_ten",
		"start_shop_appraisal_v27": "shop_appraisal_ten",
		"start_v28": "mirror_dream_ten",
		"start_fan_bargaining_v28": "fan_bargaining_ten",
		"start_v26": "mirror_reunion_ten"
	}
	var library := SaveLibrary.new("user://tests/release/library.json")
	var checks := 0
	for scene_name in cases:
		var scene: Node = load("res://scenes/%s.tscn" % scene_name).instantiate()
		var manifest: String = scene.get_node("Bootstrap").manifest_path
		scene.free()
		var loaded := JsonContentProvider.new(manifest).load_catalog()
		if not loaded.is_success() or loaded.catalog.default_run_id != cases[scene_name]:
			push_error("Wrong scene/catalog: " + scene_name); quit(1); return
		var run := loaded.catalog.get_definition("runs",loaded.catalog.default_run_id) as RunDefinition
		var store := GhostReplayStore.new()
		store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
		var session := RunSession.new(run,loaded.catalog.content_version,store,loaded.catalog)
		var restored := library.decode_entry({"format":1,"saved_at":"2026-09-22","payload":SaveCodec.new().encode(session._day.state,loaded.catalog.content_version)})
		if restored.is_empty() or restored.run.id != run.id or not GhostSaveCodec.same(restored.state.to_read_model(),session.read_state()):
			push_error("Cross-run save collision: " + scene_name + " " + library.error_message); quit(1); return
		checks += 2
	print("RELEASE ENTRY COMPATIBILITY: %d checks passed" % checks)
	quit(0)
