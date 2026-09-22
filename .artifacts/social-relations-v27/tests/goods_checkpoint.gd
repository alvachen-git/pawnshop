extends SceneTree

const QA := "res://.godot/qa/goods/"
var checks := 0
var failures := 0
var catalog: ContentCatalog
var run_def: RunDefinition
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL " + label)
func reject(data: Dictionary, label: String) -> void:
	var codec := SaveCodec.new()
	check(codec.decode(data, run_def, 21, catalog, true) == null, label)

func run() -> void:
	catalog = JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	var library := SaveLibrary.new(QA + "process_library.json")
	if "read" in OS.get_cmdline_user_args():
		for key in ["manual/1", "auto/goods_expertise_seven", "manual/2", "auto/pawn_chance_seven"]:
			check(not library.read_entry(key).is_empty(), "cross process library " + key)
		var manager := SaveManager.new(QA + "unused.json"); manager.library = library
		var session := RunSession.new(run_def, 21, manager, catalog)
		check(library.adopt(library.read_entry("manual/2"), session) and session.content_version == 20, "old version restore")
		session.new_run()
		check(session.content_version == 21 and session.definition.id == "goods_expertise_seven", "new game returns to v21")
	else:
		for seed_value in (range(32) if "economy" in OS.get_cmdline_user_args() else range(3)):
			for night in range(1, 8):
				var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QA + "review_%d_%d.json" % [seed_value, night]))
				var codec := SaveCodec.new(); var state := codec.decode(data, run_def, 21, catalog, true)
				check(state != null, "cross process %d/%d: %s" % [seed_value, night, codec.error_message])
				if state == null: continue
				if not data.expertise_history.is_empty():
					for key in ["fee", "result", "start", "item_ids"]:
						var bad := data.duplicate(true)
						bad.expertise_history[0][key] = {"fee": 0, "result": "forged", "start": 0, "item_ids": ["missing"]}[key]
						if bad != data: reject(bad, "reject expert " + key)
					var bad := data.duplicate(true); bad.expertise_history.append(bad.expertise_history[0].duplicate(true)); reject(bad, "reject duplicate certificate")
				for item in data.inventory_instances:
					if item.definition_id == GoodsExpertise.FAN:
						var bad := data.duplicate(true); bad.inventory_instances[data.inventory_instances.find(item)].expert_reviewed = not item.get("expert_reviewed", false); reject(bad, "reject forged fan certification"); break
				for item in data.inventory_instances:
					if item.definition_id == GoodsExpertise.CUP:
						var bad := data.duplicate(true); bad.inventory_instances[data.inventory_instances.find(item)].goods.workshop = 1 - int(item.goods.workshop); reject(bad, "reject forged workshop"); break
				for batch in data.sale_batches:
					if not batch.get("pairs", []).is_empty():
						var bad := data.duplicate(true); bad.sale_batches[data.sale_batches.find(batch)].pairs.append(batch.pairs[0].duplicate()); reject(bad, "reject duplicate pair bonus"); break
				if seed_value == 0 and night == 1:
					for key in ["manual/1", "auto/goods_expertise_seven"]: check(library.write_entry(key, state, run_def, 21, catalog), "write " + key)
					var bytes := FileAccess.get_file_as_bytes(library.path)
					library.fail_write = true
					check(not library.write_entry("manual/1", state, run_def, 21, catalog) and bytes == FileAccess.get_file_as_bytes(library.path), "manual write failure preserves file")
					library.fail_write = false
					var manager := SaveManager.new(QA + "unused.json"); manager.library = library
					var session := RunSession.new(run_def, 21, manager, catalog)
					check(library.adopt(library.read_entry("manual/1"), session), "adopt checkpoint")
					var driver = preload("res://tests/integrated_test_driver.gd").new(); driver.check = check; driver.catalog = catalog; driver.drain(session)
					var before := session._day.state.to_read_model(); library.fail_write = true
					var target := session._day.state.inventory_instances[0].instance_id
					check(not session.execute("prep_seek", target).ok and session._day.state.to_read_model() == before, "seeking disk rollback")
					library.fail_write = false
		var old := JsonContentProvider.new("res://data/pawn_chance_manifest.json").load_catalog().catalog
		var old_run := old.get_definition("runs", old.default_run_id) as RunDefinition
		var old_session := RunSession.new(old_run, 20, SaveManager.new(QA + "unused20.json"), old)
		check(not old_session.read_state().has("expertise_history"), "old state shape unchanged")
		for key in ["manual/2", "auto/pawn_chance_seven"]: check(library.write_entry(key, old_session._day.state, old_run, 20, old), "old slot alongside v21")
	print("GOODS CHECKPOINT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
