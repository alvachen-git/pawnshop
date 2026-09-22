extends Node

@export var start_at_title := false
var title_menu: TitleMenuView
var storage: SaveLibraryView
var _initial_run_ready := true

@onready var _bootstrap: Bootstrap = $Bootstrap
@onready var _counter_screen: CounterScreen = $CounterScreen


func _ready() -> void:
	if OS.is_debug_build():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--condition-preview=") and argument.trim_prefix("--condition-preview=") in ["upgrade", "fan-sound", "informed-ready", "ordinary-ready", "urgent-ready", "no-bench", "intact", "minor", "major", "stack", "knowledge-before"]:
				_bootstrap.condition_preview = argument.trim_prefix("--condition-preview=")
				start_at_title = false
			if argument.begins_with("--bargaining-preview=") and argument.trim_prefix("--bargaining-preview=") in ["upgrade", "fan-sound", "informed-ready", "ordinary-ready", "urgent-ready"]:
				_bootstrap.bargaining_preview = argument.trim_prefix("--bargaining-preview=")
				start_at_title = false
			if argument.begins_with("--appraisal-preview=") and argument.trim_prefix("--appraisal-preview=") in ["upgrade", "ready", "fan-sound", "fan-mended", "fan-flawed"]:
				_bootstrap.appraisal_preview = argument.trim_prefix("--appraisal-preview=")
				start_at_title = false
			if argument.begins_with("--growth-preview=") and argument.trim_prefix("--growth-preview=") in ["preparation", "closed", "buyer"]:
				_bootstrap.growth_preview = argument.trim_prefix("--growth-preview=")
				start_at_title = false
			if argument.begins_with("--mirror-reunion-preview=") and argument.trim_prefix("--mirror-reunion-preview=") in ["ready", "apology", "angry", "evasive"]:
				_bootstrap.preview_stage = argument.trim_prefix("--mirror-reunion-preview=")
				_bootstrap.preview_version = 26
				start_at_title = false
			if argument.begins_with("--mirror-ending-preview=") and argument.trim_prefix("--mirror-ending-preview=") in ["ready", "willing", "refused"]:
				_bootstrap.preview_stage = argument.trim_prefix("--mirror-ending-preview=")
				_bootstrap.preview_version = 25
				start_at_title = false
			if argument.begins_with("--investigation-preview=") and argument.trim_prefix("--investigation-preview=") in ["commission", "report", "meeting"]:
				_bootstrap.preview_stage = argument.trim_prefix("--investigation-preview=")
				start_at_title = false
	_initial_run_ready = start_at_title
	if start_at_title:
		_counter_screen.hide()
		_counter_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_bootstrap.content_ready.connect(_counter_screen.show_content_ready)
	_bootstrap.content_failed.connect(_counter_screen.show_content_error)
	_bootstrap.initialize()
	if _bootstrap.session != null:
		if start_at_title: _bootstrap.session.message = RunSession.NEW_RUN_MESSAGE
		_counter_screen.bind_session(_bootstrap.session)
	if _bootstrap.session != null and _bootstrap.session._save.library != null:
		storage = SaveLibraryView.new()
		add_child(storage)
		storage.bind(_bootstrap.session)
		storage.loaded.connect(_enter_game)
		storage.leave_confirmed.connect(_leave)
		get_tree().auto_accept_quit = false
	if start_at_title:
		_show_title()
		_warm_counter.call_deferred()
	if not _bootstrap.preview_stage.is_empty() and _bootstrap.session != null:
		_counter_screen.get_node("%ScreenFlowCoordinator").show_panel.call_deferred(&"risk" if _bootstrap.preview_version >= 25 else &"dialogue" if _bootstrap.preview_stage == "meeting" else &"investigation")
	if not _bootstrap.growth_preview.is_empty() and _bootstrap.session != null:
		_counter_screen.get_node("%ScreenFlowCoordinator").show_panel.call_deferred(&"trade" if _bootstrap.growth_preview == "buyer" else &"growth")
		if _bootstrap.growth_preview == "closed": _counter_screen.facilities.room.select.call_deferred("archive")
	if not _bootstrap.appraisal_preview.is_empty() and _bootstrap.session != null: _open_appraisal_preview.call_deferred()
	if not _bootstrap.condition_preview.is_empty() and _bootstrap.session != null:
		if _bootstrap.condition_preview == "knowledge-before":
			_open_knowledge_preview.call_deferred()
		elif _bootstrap.condition_preview in ["upgrade", "fan-sound"]:
			_bootstrap.appraisal_preview = _bootstrap.condition_preview
			_open_appraisal_preview.call_deferred()
		else: _open_condition_preview.call_deferred()
	if not _bootstrap.bargaining_preview.is_empty() and _bootstrap.session != null: _open_bargaining_preview.call_deferred()

func _open_knowledge_preview() -> void:
	_counter_screen.get_node("%ScreenFlowCoordinator").show_panel(&"growth")
	_counter_screen.facilities.room.select("knowledge/gu_yansheng")

func _open_bargaining_preview() -> void:
	if _bootstrap.bargaining_preview.ends_with("-ready"):
		_counter_screen.get_node("%ScreenFlowCoordinator").show_panel(&"trade")
	else:
		_bootstrap.appraisal_preview = _bootstrap.bargaining_preview
		_open_appraisal_preview()

func _open_appraisal_preview() -> void:
	if _bootstrap.appraisal_preview.begins_with("fan-"):
		_counter_screen.get_node("%ScreenFlowCoordinator").show_panel(&"appraisal")
		var visit := CustomerManager.new().active(_bootstrap.session._day.state)
		if visit != null: FanAppraisalView.open(_counter_screen, _bootstrap.session, visit.item.instance_id)
	else:
		_counter_screen.get_node("%ScreenFlowCoordinator").show_panel(&"growth")
		_counter_screen.facilities.room.select("bench")

func _warm_counter() -> void:
	# Draw once behind the opaque title to upload textures and cache font glyphs.
	# Gameplay processing stays disabled throughout this first-frame warmup.
	if DisplayServer.get_name() == "headless" or not is_instance_valid(title_menu): return
	_counter_screen.show()
	await RenderingServer.frame_post_draw
	if is_instance_valid(title_menu) and title_menu.visible:
		_counter_screen.hide()

func _show_title() -> void:
		title_menu = TitleMenuView.new()
		title_menu.name = "TitleMenu"
		add_child(title_menu)
		title_menu.new_requested.connect(_start_new_game)
		title_menu.load_requested.connect(_load_game)
		title_menu.exit_requested.connect(_exit_game)
		title_menu.configure(_bootstrap.session != null, _bootstrap.session != null and _bootstrap.session.has_save())


func _start_new_game() -> void:
	if _bootstrap.session == null: return
	# Bootstrap already generated this untouched first night, including its seed.
	if not _initial_run_ready: _bootstrap.session.new_run()
	_enter_game()


func _load_game() -> void:
	if storage != null:
		storage.open("load")
		return
	if _bootstrap.session == null: return
	var result := _bootstrap.session.load_checkpoint()
	if result.ok: _enter_game()
	else: title_menu.show_error(result.message)


func _enter_game() -> void:
	_initial_run_ready = false
	_counter_screen.process_mode = Node.PROCESS_MODE_INHERIT
	_counter_screen.show()
	if is_instance_valid(title_menu):
		title_menu.hide()
		title_menu.queue_free()
	_counter_screen.focus_active_screen()


func _exit_game() -> void:
	if storage != null and not is_instance_valid(title_menu): storage.request_leave("quit")
	else: get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _exit_game()

func _leave(destination: String) -> void:
	if destination == "quit": get_tree().quit(); return
	_counter_screen._cancel_feedback(true)
	storage.close()
	_counter_screen.hide()
	_counter_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_show_title()

func _open_condition_preview() -> void:
	_counter_screen.get_node("%ScreenFlowCoordinator").show_panel(&"appraisal")
