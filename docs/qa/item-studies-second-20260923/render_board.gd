extends SceneTree
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	root.size=Vector2i(1600,900); root.content_scale_size=root.size
	var bg=ColorRect.new(); bg.color=Color("292923"); bg.size=Vector2(root.size); root.add_child(bg)
	var names=["folding_fan_back","inkstone_back","clay_teapot_back","silk_panel_back","pocket_watch_sound_macro","pocket_watch_flawed_macro"]
	var labels=["折扇 · 背面","砚台 · 底面","紫砂小壶 · 背面","花鸟绣片 · 背面","怀表 · 完好轴孔","怀表 · 轴孔磨损"]
	for i in names.size():
		var box=VBoxContainer.new();box.position=Vector2(28+(i%3)*524,24+(i/3)*438);box.size=Vector2(504,412);root.add_child(box)
		var label=Label.new();label.text=labels[i];label.add_theme_font_size_override("font_size",24);box.add_child(label)
		var picture=TextureRect.new();picture.texture=load("res://assets/item_studies_second/"+names[i]+".png");picture.expand_mode=1;picture.stretch_mode=5;picture.size_flags_vertical=3;box.add_child(picture)
	await process_frame; await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa/item-studies-second-20260923/art-board.png")
	quit()
