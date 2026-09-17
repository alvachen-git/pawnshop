extends "res://tests/shop_growth_ui.gd"

var nav: FacilitiesNavigation
var facilities_view: FacilitiesRoomView

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("FACILITIES TIMEOUT"); quit(1))
	_capture_prefix = "facilities_1600" if "wide" in OS.get_cmdline_user_args() else "facilities_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start_shop_growth.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/facilities_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new()
	store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	install("preparation")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	nav = screen.facilities
	facilities_view = nav.room
	screen._close_drawer()
	await _frames()
	var before := _session.read_state()
	await _capture("10_counter_entry")
	await _move(Vector2(root.size.x * 0.5, 160))
	await _move(Vector2(2, 170))
	await create_timer(0.15).timeout
	_check(not nav.in_room, "short edge pass does not navigate")
	await _move(Vector2(200, 170))
	await _move(Vector2(2, 170))
	await create_timer(0.90).timeout
	_check(nav.in_room and not nav.transitioning and _main.find_child("ReduceFacilitiesMotion", true, false) == null, "left-edge dwell completes default fade without motion toggle")
	_check(_session.read_state() == before, "navigation changes no money time inventory preparation journal or random opportunity")
	await _capture("01_initial")
	await _move(facilities_view.return_button.get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _capture("09_return_hover")
	await _click_button(facilities_view.return_button)
	await create_timer(0.6).timeout
	_check(not nav.in_room and _session.read_state() == before, "icon-only arrow returns without changing run state")
	nav.enter("", false)
	await _move(Vector2(200, 170))
	await _move(Vector2(root.size.x - 2, 170))
	await create_timer(0.90).timeout
	_check(not nav.in_room and not nav.transitioning, "right-edge dwell returns to counter")
	await _move(Vector2(200, 170))
	await _move(Vector2(2, 170))
	nav._clear_pointer()
	await create_timer(0.55).timeout
	_check(not nav.in_room, "leaving window cancels edge dwell")
	nav.enter()
	await create_timer(0.05).timeout
	_check(nav.transitioning and facilities_view.hotspots.bench.disabled and facilities_view.position.x == 0 and screen._counter_view.position.x == 0, "fade disables duplicate input without horizontal motion")
	await _capture("07_fade")
	await create_timer(0.4).timeout
	nav.leave()
	await create_timer(0.3).timeout
	_check(not nav.in_room and not nav.transitioning, "default fade returns cleanly")
	nav.enter()
	await create_timer(0.3).timeout
	_check(nav.in_room and facilities_view.modulate.a == 1, "default fade restores full opacity")
	nav.leave()
	await create_timer(0.1).timeout
	var original_size := root.size
	root.size += Vector2i(16, 9)
	await create_timer(0.15).timeout
	_check(not nav.transitioning and not nav.in_room and screen._counter_view.position.x == 0, "resize during fade settles scene positions")
	root.size = original_size
	await _frames()
	nav.enter("", false)
	_check(_session.read_state() == before, "all navigation alternatives preserve exact run state")
	await _click_button(facilities_view.hotspots.bench)
	await _move(Vector2(root.size.x - 2, 170))
	await create_timer(0.55).timeout
	_check(nav.in_room, "open paper blocks edge navigation")
	_check(facilities_view.body.text.contains("40银元"), "bench paper exposes price")
	await _capture("02_bench_paper")
	var real_manager := SaveManager.new("user://tests/facilities_ui/disk.json")
	real_manager.catalog = _session._counter.catalog
	real_manager.library = SaveLibrary.new("user://tests/facilities_ui/library.json")
	_check(real_manager.save_state(_session._day.state, _session.definition, 25), "prepare real atomic save")
	_session._save = real_manager
	real_manager.library.fail_write = true
	await _click("整修鉴物台 · 40银元 / 准备1次")
	_check(not _session._day.state.shop_growth.bench and not facilities_view._shader.get_shader_parameter("bench_built"), "failed real save rolls back facility appearance")
	_check(_session.read_state() == before and not facilities_view.status_note.text.is_empty(), "failed real save retains full state and visible error")
	real_manager.library.fail_write = false
	await _click("整修鉴物台 · 40银元 / 准备1次")
	_check(_session._day.state.shop_growth.bench and not _session._day.state.shop_growth.display, "bench purchase independent from cabinet")
	_check(facilities_view._shader.get_shader_parameter("bench_built") and not facilities_view._shader.get_shader_parameter("display_built"), "mixed repair art follows only purchased facility")
	await _key(KEY_ESCAPE)
	await _capture("03_bench_only")
	await _click_button(facilities_view.hotspots.display)
	await _click("整修陈列柜 · 60银元 / 准备1次")
	_check(_session._day.state.cash == before.cash - 100 and PreparationService.count(_session._day.state) == 2, "scene actions share exact preparation and cost")
	await _click("陈列：银簪")
	_check(facilities_view.stock_picture.visible and not facilities_view.stock_id.is_empty(), "real selected inventory stock appears in empty cabinet")
	await _capture("04_displayed")
	await _click("撤下陈列货 · 不耗时")
	_check(not facilities_view.stock_picture.visible, "withdraw removes painted stock")
	await _click("陈列：银簪")
	var restored := real_manager.load_state(_session.definition, 25)
	_check(restored != null and restored.shop_growth == _session._day.state.shop_growth, "scene operations persist real compatible save")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await create_timer(0.6).timeout
	_check(not nav.in_room, "Escape closes paper then returns to counter")
	await _click_button(screen.get_node("%MenuButton"))
	await _click("修缮与查铺")
	await create_timer(0.6).timeout
	_check(nav.in_room and not screen.get_node("%Drawer").visible, "existing shop menu routes into full facilities scene")
	install("closed")
	screen._close_drawer()
	await _frames()
	await _click_button(nav.entry)
	await create_timer(0.6).timeout
	await _click_button(facilities_view.hotspots.archive)
	_check(not facilities_view.body.text.contains("顾敬堂") and not facilities_view._compartment.visible, "secret evidence not revealed before investigation")
	await _click("整理旧账 · 15分钟")
	_check(facilities_view.body.text.contains("旧柜目录") and not facilities_view._compartment.visible, "first exploration reveals only acquired directory")
	await _capture("05_directory")
	await _click("核对柜号 · 15分钟")
	await _click("检查夹板 · 20分钟")
	_check(_session._day.state.shop_growth.exploration.size() == 3 and facilities_view._compartment.visible, "three-step real exploration reveals compartment sprite")
	await _capture("06_compartment")
	before = _session.read_state()
	await _key(KEY_ESCAPE)
	await _click_button(facilities_view._materials)
	_check(_session.read_state() == before, "rereading material costs nothing and creates no journal")
	# Forced events cannot be bypassed even if queued while standing inside this room.
	_session._day.state.pending_event_id = "evt_intro_first_trade"
	nav._sync()
	await _frames()
	_check(not nav.in_room and not nav.available(), "forced pending immediately restores original priority")
	install("preparation")
	screen._close_drawer()
	_session._day.state.cash = 0
	_session.changed.emit()
	await _frames()
	await _click_button(nav.entry)
	await create_timer(0.6).timeout
	await _click_button(facilities_view.hotspots.display)
	var unavailable := _find_button(_main, "整修陈列柜 · 60银元 / 准备1次")
	_check(unavailable != null and unavailable.disabled and unavailable.tooltip_text.contains("现银不足"), "insufficient cash disables purchase with clear reason")
	install("preparation")
	screen._close_drawer()
	await _frames()
	nav.enter("display", false)
	await _click("整修陈列柜 · 60银元 / 准备1次")
	_check(not facilities_view._shader.get_shader_parameter("bench_built") and facilities_view._shader.get_shader_parameter("display_built"), "display-only repair leaves bench worn")
	await _key(KEY_ESCAPE)
	await _capture("08_display_only")
	install("buyer")
	screen._close_drawer()
	await _frames()
	await _click_button(nav.entry)
	await create_timer(0.6).timeout
	_check(facilities_view._notice.visible, "existing buyer remains present while browsing room")
	before = _session.read_state()
	await create_timer(0.6).timeout
	_check(_session.read_state() == before, "real seconds in facilities do not change action-based clock or queue")
	await _click_button(facilities_view._notice)
	await create_timer(0.6).timeout
	await buyer_page()
	var buyer_panel := _find_trade_panel(_main)
	buyer_panel._growth_amount.text = "123"
	await _move(Vector2(root.size.x * 0.5, 160))
	await _move(Vector2(2, 170))
	await create_timer(0.55).timeout
	_check(not nav.in_room and buyer_panel._growth_amount.text == "123", "quote drawer blocks edge navigation and retains typed amount")
	await _click("接受报价 · 5分钟")
	_check(_session._day.state.sale_records.size() == 1 and _session._day.state.shop_growth.display_id.is_empty(), "buyer still sells exactly once through original counter")
	await receipts()
	# Standalone preview has no Bootstrap or RunSession and no way to submit game commands.
	_main.queue_free()
	await _frames()
	_main = load("res://scenes/facilities_preview.tscn").instantiate()
	root.add_child(_main)
	await _frames()
	var preview: FacilitiesRoomView = _main.room
	_check(preview.session == null and _main.find_child("Bootstrap", true, false) == null, "preview is independent from gameplay storage and session")
	for level in 4:
		await _click_button(preview._preview_bar.get_child(level))
		_check(preview.preview_level == level, "preview selects level %d" % level)
		_check(preview._numbers.size() == 16 and not preview.stock_picture.visible, "preview has sixteen runtime numbers and no baked stock")
		await _capture("preview_%d" % level)
	await _click_button(preview.hotspots.archive)
	_check(preview.body.text.contains("方式尚待定稿") and preview.actions.get_child_count() == 0, "preview archive is explicit visual plan not paid investigation")
	await _capture("preview_archive")
	print("FACILITIES UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func _move(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()
