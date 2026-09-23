extends "res://tests/item_study_art_ui.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_capture_prefix = "v37_" + str(root.size.x)
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/item-studies/atlas-auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/item-studies/atlas-library.json"
	await _frames()
	_check(_session.content_version == 37, "default entry retains latest campaign")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	for item in ["gold_watch", "embroidery", "gold_watch"]:
		PrecisionPreview.apply(_session,2,item)
		_session.restored.emit(); _session.changed.emit(); await _frames()
		screen._flow.show_panel(&"appraisal"); await _frames()
		var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
		_check(panel._image.is_visible_in_tree() and panel._image.texture != null, "new atlas remains visible " + item)
		_check(not panel._views.visible, "atlas does not expose ordinary study tabs")
		if item == "gold_watch":
			_check(panel._image.material != null and panel._image.material.shader.resource_path.ends_with("watch_cutout.gdshader"), "watch retains its own material")
		else:
			_check(panel._image.material == null, "non-watch atlas clears previous watch material")
		await _capture("atlas_" + item)
	print("ITEM STUDY ATLAS UI: %d assertions, %d failures" % [_assertions,_failures])
	quit(0 if _failures == 0 else 1)
