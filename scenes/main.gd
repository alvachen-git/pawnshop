extends Node

@export var start_at_title := false
var title_menu: TitleMenuView
var storage: SaveLibraryView

@onready var _bootstrap: Bootstrap = $Bootstrap
@onready var _counter_screen: CounterScreen = $CounterScreen


func _ready() -> void:
	if start_at_title:
		_counter_screen.hide()
		_counter_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_bootstrap.content_ready.connect(_counter_screen.show_content_ready)
	_bootstrap.content_failed.connect(_counter_screen.show_content_error)
	_bootstrap.initialize()
	if _bootstrap.session != null:
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
	_bootstrap.session.new_run()
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
