extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(660, 880); root.content_scale_size = root.size
	var catalog := JsonContentProvider.new("res://data/first_debt_manifest.json").load_catalog().catalog
	for id in ["fd_ticket", "fd_receipt", "fd_family"]:
		var e := catalog.get_definition("events", id) as EventDefinition
		var paper := FirstDebtDocument.new()
		paper.configure({"id": id, "title": e.title, "text": e.choices[0].result})
		root.add_child(paper); paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var path: String = "res://assets/first_debt/" + id.trim_prefix("fd_") + ".png"
		if root.get_texture().get_image().save_png(path) != OK: quit(1); return
		paper.queue_free(); await process_frame
	print("THREE AUTHORITATIVE PAPER ASSETS RENDERED")
	quit()
