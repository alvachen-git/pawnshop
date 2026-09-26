extends SceneTree
var main: Node
var session: RunSession
var passes := 0
var failures := 0
var wide := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1; push_error(label)
func frames(n := 8) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	root.get_texture().get_image().save_png("res://.godot/qa/town-life/%s_%s.png" % ["1600" if wide else "1280",label])
func run() -> void:
	wide = "wide" in OS.get_cmdline_user_args()
	main = load("res://scenes/town_life_v50_start.tscn" if "v50" in OS.get_cmdline_user_args() else "res://scenes/town_life_v49_start.tscn" if "v49" in OS.get_cmdline_user_args() else "res://scenes/town_life_start.tscn").instantiate(); main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/town-ui/auto.json"
	root.add_child(main); current_scene = main
	session = main.get_node("Bootstrap").session
	await frames(12)
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1600,900) if wide else Vector2i(1280,720); root.content_scale_size = root.size
	await frames();DirAccess.make_dir_recursive_absolute("res://.godot/qa/town-life")
	check(root.get_texture().get_image().get_size()==root.size,"actual resolution")
	var screen := main.get_node("CounterScreen") as CounterScreen
	for profession in ["porter","musician","washerwoman","soldier"]:
		TownLifePreview.apply(session,profession);session.restored.emit();session.changed.emit();await frames(12);await create_timer(0.6).timeout
		screen._close_drawer();await frames()
		check(screen._counter_view._portrait.texture.resource_path.ends_with(profession+".png"),"dedicated portrait "+profession)
		check(screen._counter_view._portrait.modulate.a>.99,"portrait visible")
		capture(profession)
		screen._route_from_customer(&"trade");await frames();capture(profession+"_trade")
		var model:=session.counter_model();check(not JSON.stringify(model).contains("looted_from_dead"),"no hidden provenance")
		if profession=="porter":check(model.trade.body.contains("赶工价"),"deadline and price shown")
		if profession=="musician":check(not model.trade.can_offer and model.trade.can_pawn,"erhu pawn only UI")
		screen._close_drawer()
	for item in TownLife.items(session.definition):
		TownLifePreview.apply(session,"goods",item);session.restored.emit();session.changed.emit();await frames(12);await create_timer(.5).timeout
		screen._close_drawer();await frames();capture(item)
		check(screen._counter_view._item_image.texture!=null,"visible item "+item)
		screen._route_from_item(&"appraisal");await frames();capture(item+"_appraisal");screen._close_drawer()
	TownLifePreview.apply(session,"military");session.restored.emit();session.changed.emit();await frames(12)
	screen._route_from_counter(&"social",&"social");await frames();screen._social_panel.section=0;screen._social_panel.refresh();await frames()
	capture("military")
	var model:=FactionBookModels.page(session._day,"military",0)
	check(model.title.contains("御寒衣物"),"mixed procurement title")
	check(model.stock.size()==3,"only eligible choices visible")
	check(JSON.stringify(model.stock).contains("夹棉背心") and JSON.stringify(model.stock).contains("棉袄"),"actual item names")
	print("TOWN UI: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)
