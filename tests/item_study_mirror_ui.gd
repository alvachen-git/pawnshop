extends "res://tests/item_study_art_ui.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	_capture_prefix = str(root.size.x)
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = "res://.godot/qa/item-studies/mirror-auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/item-studies/mirror-library.json"
	await _frames()
	for ending in ["acknowledged", "resentment"]:
		var codec := SaveCodec.new()
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/unified-campaign/" + ending + ".json"))
		var restored := codec.decode(data, _session.definition, 30, _session._counter.catalog, true)
		_check(restored != null, "valid actual ending fixture " + codec.error_message)
		if restored == null: continue
		_session._day.state = restored; _session.message = ""
		_session.restored.emit(); _session.changed.emit(); await _frames()
		var screen := _main.get_node("CounterScreen") as CounterScreen
		screen._flow.show_panel(&"inventory"); await _frames()
		var asset := "asset.weeping_mirror_" + String(restored.mirror_resolution.ability)
		var path := CounterItemArt.front_path(asset)
		var picture := find_picture(screen, path)
		_check(picture != null and picture.is_visible_in_tree(), "actual ending inventory uses new state PNG " + ending)
		if picture == null: continue
		var parent := picture.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(picture.get_parent().get_parent())
			parent = parent.get_parent()
		await _frames(); await _capture("mirror_" + ending + "_inventory")
		await _comparison(picture, "mirror_" + ending)
	print("ITEM STUDY MIRROR UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func find_picture(node: Node, path: String) -> TextureRect:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path: return node
	for child in node.get_children():
		var found := find_picture(child, path)
		if found != null: return found
	return null
