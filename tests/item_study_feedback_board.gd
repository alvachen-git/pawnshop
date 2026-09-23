extends SceneTree
const ROWS := [
 [["银戒指 · 磨痕 / 调整前","before_ring_sound"],["银戒指 · 磨痕 / 调整后","silver_ring_sound"],["银戒指 · 露铜 / 调整前","before_ring_flaw"],["银戒指 · 露铜 / 调整后","silver_ring_flaw"]],
 [["银锁 · 磨痕 / 调整前","before_lock_sound"],["银锁 · 磨痕 / 调整后","silver_lock_sound"],["银锁 · 露铜 / 调整前","before_lock_flaw"],["银锁 · 露铜 / 调整后","silver_lock_flaw"]]
]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,720); root.content_scale_size = root.size
	var bg := ColorRect.new(); bg.color = Color("25241f"); bg.size = Vector2(root.size); root.add_child(bg)
	var font := load("res://assets/fonts/NotoSansSC.ttf")
	var title := Label.new(); title.text = "鬼市当铺  /  磨痕与露铜 · 调整前后"; title.position = Vector2(28,18); title.add_theme_font_override("font",font); title.add_theme_font_size_override("font_size",28); root.add_child(title)
	for y in ROWS.size():
		for x in ROWS[y].size():
			var row: Array = ROWS[y][x]
			var card := ColorRect.new(); card.position = Vector2(24+x*390,78+y*305); card.size=Vector2(376,292); card.color=Color("343129"); root.add_child(card)
			var label := Label.new(); label.text=row[0]; label.position=Vector2(12,8); label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",19); card.add_child(label)
			var picture:=TextureRect.new(); picture.position=Vector2(10,42); picture.size=Vector2(356,238); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if String(row[1]).begins_with("before_"):
				var filename: String = String(row[1]).trim_prefix("before_")
				picture.texture = ImageTexture.create_from_image(Image.load_from_file("res://docs/qa/item-studies-20260923/feedback-before/silver_"+filename+".png"))
			else: picture.texture=load(CounterItemArt.STUDY_ROOT+row[1]+".png")
			picture.material=CounterVisualCatalog.study_material(picture.texture); card.add_child(picture)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/item-studies/"))
	root.get_texture().get_image().save_png("res://.godot/qa/item-studies/detail-feedback-board.png")
	quit()
