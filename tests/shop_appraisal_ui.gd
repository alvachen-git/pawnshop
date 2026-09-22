extends "res://tests/shop_growth_ui.gd"

class DraftUIStore extends GhostReplayStore:
	var fail := false
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		return not fail

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-appraisal/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 27, _session._counter.catalog, true)
	_check(state != null, "valid unified UI fixture " + codec.error_message)
	if state == null: return
	_session._day.state = state
	_session.message = ""
	_session.restored.emit()
	_session.changed.emit()

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("APPRAISAL UI TIMEOUT"); quit(1))
	_capture_prefix = "appraisal_1600" if "wide" in OS.get_cmdline_user_args() else "appraisal_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start_shop_appraisal_v27.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/appraisal_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := DraftUIStore.new()
	store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 27 and _session.definition.id == "shop_appraisal_ten", "unified default new game")
	install("upgrade")
	await service()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var room := screen.facilities.room
	await _click_button(room.hotspots.bench)
	await _capture("01_upgrade")
	await _click("改造二级鉴物台 · 80银元 / 准备1次 / 两夜工期")
	_check(int(FanAppraisalService.data(_session._day.state).bench_due) == 5, "real mouse starts two-night construction")
	_check(not room._shader.get_shader_parameter("bench_specialized"), "construction does not show completed bench")
	install("ready")
	await service()
	await _click_button(room.hotspots.bench)
	await _frames()
	_check(room.is_visible_in_tree() and screen.facilities.in_room, "completed bench is actually visible")
	_check(room._shader.get_shader_parameter("bench_specialized"), "completed bench uses level two artwork")
	_check(not room._shader.get_shader_parameter("display_built"), "bench does not upgrade showcase")
	await _capture("02_bench_ready")
	screen.facilities.leave(false)
	install("fan-sound")
	await _frames()
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"appraisal")
	await _frames()
	var before := _session.read_state()
	await _click("扇画比对 · 查看图录与手记")
	var view := root.get_node_or_null("FanAppraisalOverlay") as FanAppraisalView
	_check(view != null and _session.read_state() == before, "opening comparison only reads")
	if view == null: quit(1); return
	await _frames()
	await _capture("03_compare_unseen")
	var start := _session._day.state.game_minutes
	var origin := view.book.position
	await desk_drag(view.book, Vector2(18, -8))
	_check(view.book.position.distance_to(origin) > 5, "book physically drags")
	_check(_session.read_state() == before, "moving objects is free and not journaled")
	await _click_button(_find_button(view, "归位"))
	_check(view.book.position == origin and _session.read_state() == before, "reset placement stays free")
	await desk_select(view.book, Vector2(0.72, 0.32))
	await desk_select(view.fan, Vector2(0.8, 0.355))
	_check(view.note_buttons.same.disabled, "mismatched evidence types cannot be recorded")
	await desk_select(view.fan, Vector2(0.38, 0.245))
	_check(not view.note_buttons.same.disabled, "two manually selected points enable recording")
	await _capture("03_brush_pair")
	if "wide" in OS.get_cmdline_user_args():
		root.size = Vector2i(1672, 941)
		root.content_scale_size = root.size
		await _frames()
		await _capture("03_reference_size")
		root.size = Vector2i(1600, 900)
		root.content_scale_size = root.size
		await _frames()
	await _click_button(_find_button(view, "放大"))
	_check(view.zoom.visible and _session.read_state() == before, "actual detail zoom is free")
	await _capture("04_zoom_brush")
	await _click_button(_find_button(view, "收起放大"))
	await _click_button(view.note_buttons.same)
	_check(_session._day.state.game_minutes == start, "UI brush draft is free")
	await _click_button(view.note_buttons.different)
	_check(FanAppraisalService.notes(_session._day.state,view.item_id).brush.note == "different", "UI reselects existing opinion")
	await _click_button(view.clear_all)
	_check(FanAppraisalService.notes(_session._day.state,view.item_id).is_empty(), "single clear button clears draft")
	await desk_select(view.book, Vector2(.72,.32))
	await desk_select(view.fan, Vector2(.38,.245))
	await _click_button(view.note_buttons.same)
	await desk_select(view.book, Vector2(0.74, 0.69))
	await desk_select(view.fan, Vector2(0.80, 0.355))
	await _capture("04_compare_evidence")
	await _click_button(view.note_buttons.unsure)
	_check(_session._day.state.game_minutes == start, "UI inscription draft is free")
	var pairs := FanAppraisalService.notes(_session._day.state, view.item_id)
	_check(pairs.brush.note == "same" and pairs.inscription.note == "unsure", "player opinions retained without correction")
	await _click_button(view.clear_all)
	_check(FanAppraisalService.notes(_session._day.state,view.item_id).is_empty() and view.stamp.disabled, "UI clears all and disables incomplete commit")
	await desk_select(view.book, Vector2(.72,.32))
	await desk_select(view.fan, Vector2(.38,.245))
	await _click_button(view.note_buttons.same)
	await desk_select(view.book, Vector2(.74,.69))
	await desk_select(view.fan, Vector2(.80,.355))
	await _click_button(view.note_buttons.unsure)
	var target_id := view.item_id
	await _click_button(view.close_button)
	view = FanAppraisalView.open(screen,_session,target_id)
	await _frames()
	_check(view.record_buttons.brush.text.contains("草稿") and view.record_buttons.inscription.text.contains("看不准"), "reopening restores editable drafts")
	await _click_button(view.record_buttons.brush)
	_check(not view.clear_all.disabled, "reopened drafts can be cleared")
	_check(_session._day.state.game_minutes == start and view.book.marker.distance_to(Vector2(.72,.32)) < .002, "saved circles can be revisited free")
	await _capture("05_notes")
	await _click_button(view.stamp)
	_check(view.confirm_button.disabled and view.verdict.text.contains("暂难定论"), "decision needs explicit choice and summarizes notes")
	await _capture("06_before_choice")
	var choice: Button = view.choice_buttons.sound
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(choice.get_global_rect()), "verdict remains inside viewport")
	await _click_button(choice)
	_check(_session._day.state.game_minutes == start and not view.confirm_button.disabled, "selecting verdict does not submit")
	await _click_button(_find_button(view,"返回修改"))
	_check(_session._day.state.game_minutes == start and FanAppraisalService.record(_session._day.state,view.item_id).verdict == "", "cancel decision is free")
	await _click_button(view.stamp)
	_check(view.confirm_button.disabled,"reopening decision requires a fresh choice")
	await _click_button(choice)
	await _capture("06_confirm")
	store.fail = true
	await _click_button(view.confirm_button)
	_check(view.decision.visible and view.decision_error.text.contains("操作未保存"), "failed save keeps confirmation and visible error")
	_check(_session._day.state.game_minutes == start and FanAppraisalService.record(_session._day.state,view.item_id).verdict == "", "UI rollback restores time and verdict")
	_check(not view.confirm_button.disabled and FanAppraisalService.notes(_session._day.state,view.item_id).size() == 2, "UI retains notes and can retry")
	await _capture("06_save_retry")
	store.fail = false
	await _click_button(view.confirm_button)
	_check(_session._day.state.game_minutes == start + 10, "only explicit commit costs ten")
	_check(view.clear_all.disabled and view.note_buttons.same.disabled,"formal notes are locked")
	_check(not CustomerManager.new().active(_session._day.state).item.expert_reviewed, "self judgement never reveals expert truth")
	_check(view.verdict.text.contains("掌柜自鉴"), "self judgement clearly labelled")
	await _capture("05_self_claim")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE; escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(root.get_node_or_null("FanAppraisalOverlay") == null, "Escape closes comparison")
	print("SHOP APPRAISAL UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func desk_select(object: FanDeskObject, point: Vector2) -> void:
	var position := object.get_global_transform() * (point * object.size)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		root.push_input(event, true)
	await _frames()

func desk_drag(object: FanDeskObject, delta: Vector2) -> void:
	var start := object.get_global_rect().get_center()
	var finish := start + delta * object.get_global_transform().get_scale()
	var motion := InputEventMouseMotion.new()
	motion.position = start
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = start; down.pressed = true; down.button_index = MOUSE_BUTTON_LEFT
	root.push_input(down, true)
	motion = InputEventMouseMotion.new()
	motion.position = finish; motion.relative = finish - start; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	var up := InputEventMouseButton.new()
	up.position = finish; up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
	root.push_input(up, true)
	await _frames()
