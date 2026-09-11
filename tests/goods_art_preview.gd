extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1080); root.content_scale_size = root.size
	var groups := [[], []]
	for id in ["silver_ring", "silver_lock", "folding_fan", "tea_cup"]:
		for view in ["front", "back", "sound"]: groups[0].append(id + "_" + view)
	for id in ["silver_ring", "silver_lock", "tea_cup"]:
		for view in ["flaw", "condition_mended"]: groups[1].append(id + "_" + view)
	for pattern in 2:
		for side in 2: groups[1].append("tea_cup_pattern%d_side%d" % [pattern, side])
	for index in 2:
		var bg := ColorRect.new(); bg.color = Color("252f2b"); bg.size = Vector2(root.size); root.add_child(bg)
		var grid := GridContainer.new(); grid.columns = 4; grid.position = Vector2(32, 32); bg.add_child(grid)
		grid.add_theme_constant_override("h_separation", 20); grid.add_theme_constant_override("v_separation", 24)
		for id in groups[index]:
			var col := VBoxContainer.new(); col.custom_minimum_size = Vector2(368, 312); grid.add_child(col)
			var image := TextureRect.new(); image.texture = load("res://assets/goods_v21/" + id + ".svg"); image.custom_minimum_size = Vector2(360, 250); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; col.add_child(image)
			var label := Label.new(); label.text = id; label.add_theme_font_size_override("font_size", 18); label.modulate = Color("e6d8b6"); col.add_child(label)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/qa/goods_art_%d.png" % index)
		bg.queue_free(); await process_frame
	print("GOODS ART PREVIEWS: 22 assets rendered")
	quit()
