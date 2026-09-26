extends SceneTree
var passes:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passes+=1
	else: failures+=1;push_error(label)
func frames(count:=5) -> void:
	for i in count: await process_frame
func capture(label: String) -> void:
	await create_timer(0.3).timeout
	await frames()
	root.get_texture().get_image().save_png("res://.godot/qa/qingbang/%d_%s.png" % [root.size.x,label])
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/qingbang")
	var main: Node = load("res://scenes/start_qingbang.tscn").instantiate()
	main.start_at_title=false
	main.get_node("Bootstrap").save_path="user://tests/qingbang-ui/unused.json"
	root.add_child(main);current_scene=main
	var s: RunSession=main.get_node("Bootstrap").session
	if s==null: quit(1);return
	var screen:= main.get_node("CounterScreen") as CounterScreen
	var preview=load("res://tests/qingbang_preview.gd")
	await frames(10)
	for dimensions in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.mode=Window.MODE_WINDOWED;root.size=dimensions;root.content_scale_size=dimensions
		await frames(10)
		for stage in ["intro","fee","raid","pawn","supply","inquiry"]:
			screen._social_panel.hide()
			preview.apply(s,stage)
			await frames(10)
			var model:=s.counter_model()
			if stage in ["intro","fee","raid"]:
				check(model.itemless and model.visual.portrait_asset=="social.qingbang","dedicated itemless scene")
				check(screen.first_debt_conversation.visible,"RPG conversation visible")
				check(not screen.get_node("%Drawer").visible,"no business drawer during reception")
				check(not screen._counter_view._item_hotspot.visible,"no false pawn item")
				check(screen._counter_view._portrait.get_global_rect().end.y < dimensions.y*0.52,"portrait behind counter")
				await capture(stage)
				for j in 15:
					var conversation:=screen.first_debt_conversation
					check(conversation._text.get_content_height() <= conversation._text.size.y + 2,"page fits")
					if conversation._page >= conversation._pages.size()-1: break
					await create_timer(0.2).timeout
					conversation._next.pressed.emit()
					await frames()
			if stage=="intro": check(not FactionBookModels.roster(s._day.state).any(func(r: Dictionary)->bool:return r.id=="qingbang"),"not unlocked before introduction")
			if stage in ["supply","inquiry","fee"]:
				if stage=="fee":
					var conversation := screen.first_debt_conversation
					check(conversation._choices.get_child_count() == 2, "fee choices in RPG dialogue")
					await capture("fee_choices")
					conversation.collapse()
					conversation.reopen()
					conversation._page = conversation._pages.size()-1; conversation.display_page()
					check(conversation._choices.get_child_count() == 2, "reopen keeps both choices")
					conversation._choices.get_child(0).pressed.emit()
					await frames()
					check(s._day.state.cash == 220 and s._day.state.social.qingbang.fees.size() == 1, "UI pays once")
					check(conversation._result and conversation.visible, "payment reply stays in dialogue")
					await capture("fee_paid")
					conversation.collapse()
					await frames()
					check(not screen._social_panel.visible, "no automatic book after fee")
				screen._social_panel.selected_faction="qingbang"
				screen._social_panel.section=1 if stage=="inquiry" else 0
				screen._flow.show_panel(&"social")
				await frames(8)
				check(screen._social_panel._name.text=="沈伯钧","correct selected faction")
				check(screen._social_panel._right.get_global_rect().end.x <= dimensions.x,"book fits width")
				check(not screen._social_panel._body.text.contains("关系+") and not screen._social_panel._body.text.contains("商誉-"),"hidden scores not shown")
				if stage in ["fee","supply"]:
					for action in screen._social_panel._actions.get_children():
						check(action.get_global_rect().end.y <= screen._social_panel._scroll.get_global_rect().end.y + 2,"book actions visible without scrolling")
				await capture("book_"+stage)
			if stage=="pawn":
				screen._flow.show_panel(&"trade")
				await capture("pawn")
				check(s.counter_model().trade.body.contains("本金息费免还"),"damaged pawn explains waiver")
				check(s.counter_model().trade.buttons[0].label.contains("损毁"),"damaged pawn action")
		# Compare both representatives in the same scene and viewport.
		preview.apply(s, "fee")
		await frames(8)
		var shen_rect: Rect2 = screen._counter_view._portrait.get_global_rect()
		s._day.state.social.qingbang.dialogue = {}; s._day.state.social.qingbang.pending = {}
		s._day.state.social.intro_step = 0
		s.changed.emit(); await frames(8)
		check(screen._counter_view._portrait.get_global_rect() == shen_rect, "Sun and Shen share portrait display bounds")
		await capture("sun_comparison")
		preview.apply(s, "fee"); s._day.state.cash = 79; s.changed.emit(); await frames(8)
		var conversation := screen.first_debt_conversation
		conversation._page = conversation._pages.size()-1; conversation.display_page()
		check(conversation._choices.get_child(0).disabled and not conversation._choices.get_child(1).disabled, "poor player may refuse")
		await capture("fee_insufficient")
		conversation._choices.get_child(1).pressed.emit(); await frames(8)
		check(s._day.state.cash == 79 and s._day.state.social.qingbang.relation == -20, "UI refusal")
		await capture("fee_refused")
		conversation.collapse()
	print("QINGBANG UI: %d passes, %d failures" % [passes,failures])
	quit(0 if failures==0 else 1)
