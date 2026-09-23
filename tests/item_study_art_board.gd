extends SceneTree
const ROWS := [
	[["青花小碗 · 背面","bowl_back"],["完好釉面","bowl_intact"],["修补釉面","bowl_repair"],["接缝近看","bowl_seam"],["底足磨损","bowl_foot"]],
	[["银簪 · 背面","hairpin_back"],["旧焊口","hairpin_seam"],["原铜镜","res://assets/art06/items/mirror_front.png"],["普通镜结局","mirror_ordinary_front"],["怨镜结局","mirror_resentful_front"]],
	[["银戒指 · 正面","res://assets/item_art_v30/silver_ring_front.png"],["背面","silver_ring_back"],["实银磨痕","silver_ring_sound"],["镀层露铜","silver_ring_flaw"],["受压失圆","silver_ring_condition_mended"]],
	[["银锁 · 正面","res://assets/item_art_v30/silver_lock_front.png"],["背面","silver_lock_back"],["实银磨痕","silver_lock_sound"],["镀层露铜","silver_lock_flaw"],["旧焊修补","silver_lock_condition_mended"]]
]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	var bg := ColorRect.new(); bg.color = Color("25241f"); bg.size = Vector2(root.size); root.add_child(bg)
	var font := load("res://assets/fonts/NotoSansSC.ttf")
	var title := Label.new(); title.text = "鬼市当铺  /  鉴物图与铜镜结局"; title.position = Vector2(28,18); title.add_theme_font_override("font",font); title.add_theme_font_size_override("font_size",28); root.add_child(title)
	for y in ROWS.size():
		for x in ROWS[y].size():
			var row: Array = ROWS[y][x]
			var card := ColorRect.new(); card.position = Vector2(24+x*312,70+y*205); card.size=Vector2(300,196); card.color=Color("343129"); root.add_child(card)
			var label := Label.new(); label.text=row[0]; label.position=Vector2(12,8); label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",19); card.add_child(label)
			var picture:=TextureRect.new(); picture.position=Vector2(10,42); picture.size=Vector2(280,144); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			picture.texture=load(row[1] if String(row[1]).begins_with("res://") else CounterItemArt.STUDY_ROOT+row[1]+".png"); picture.material=CounterVisualCatalog.study_material(picture.texture); card.add_child(picture)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/item-studies/"))
	root.get_texture().get_image().save_png("res://.godot/qa/item-studies/art-board.png")
	quit()
