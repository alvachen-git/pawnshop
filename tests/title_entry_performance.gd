extends SceneTree

class CountingLibrary extends SaveLibrary:
	var list_reads := 0
	func entries() -> Array[Dictionary]:
		list_reads += 1
		return super.entries()

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames() -> void:
	for i in 5: await process_frame

func run() -> void:
	create_timer(45).timeout.connect(func() -> void: push_error("TITLE ENTRY TIMEOUT"); quit(1))
	var scene = load("res://scenes/start.tscn").instantiate()
	root.add_child(scene)
	var session: RunSession = scene._bootstrap.session
	var initial := session.read_state()
	var original: SaveLibrary = session._save.library
	check(original._catalogs.get(scene._bootstrap.manifest_path) == scene._bootstrap.catalog, "save validation reuses the validated bootstrap catalog")
	var lib := CountingLibrary.new("user://tests/title_entry_%d.json" % Time.get_ticks_usec())
	lib.register_catalog(scene._bootstrap.manifest_path, scene._bootstrap.catalog)
	session._save.library = lib
	scene.storage.library = lib
	await frames()
	check(not scene._counter_screen.visible and scene._counter_screen.process_mode == Node.PROCESS_MODE_DISABLED, "warmup restores hidden, inactive gameplay")
	check(session.read_state() == initial, "render warmup does not advance or mutate gameplay")
	var started := Time.get_ticks_usec()
	scene.title_menu.new_requested.emit()
	print("TITLE PERFORMANCE new callback ms: ", (Time.get_ticks_usec() - started) / 1000.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		print("TITLE PERFORMANCE new first draw ms: ", (Time.get_ticks_usec() - started) / 1000.0)
	check(scene._counter_screen.visible and not scene._initial_run_ready, "new game enters and consumes the initial run once")
	check(session.read_state() == initial, "first new game retains the prepared seed, visitors, archives and state")
	check(session.message == RunSession.NEW_RUN_MESSAGE, "opening copy matches later new games")
	check(not FileAccess.file_exists(lib.path), "entering a new game does not overwrite saves")
	await frames()
	for i in range(1, 7):
		check(lib.write_entry("manual/%d" % i, session._day.state, session.definition, session.content_version, session._counter.catalog), "fixture slot %d saves" % i)
	var before := FileAccess.get_file_as_bytes(lib.path)
	scene._leave("title")
	await frames()
	started = Time.get_ticks_usec()
	scene.title_menu.load_requested.emit()
	print("TITLE PERFORMANCE list callback ms: ", (Time.get_ticks_usec() - started) / 1000.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		print("TITLE PERFORMANCE list first draw ms: ", (Time.get_ticks_usec() - started) / 1000.0)
	check(scene.storage.overlay.visible and scene.storage.list.get_child_count() == 6, "load opens all six slots")
	var reads := lib.list_reads
	scene.storage.pending_key = "manual/1"
	started = Time.get_ticks_usec()
	scene.storage._commit()
	print("TITLE PERFORMANCE load callback ms: ", (Time.get_ticks_usec() - started) / 1000.0)
	check(lib.list_reads == reads, "adopting a save does not rebuild the closing list")
	check(not scene.storage.overlay.visible and scene._counter_screen.visible, "successful load closes storage and enters game")
	check(FileAccess.get_file_as_bytes(lib.path) == before, "loading preserves source save bytes")
	check(session._day.state.run_token != initial.run_token, "loading creates a fresh attempt token")
	await frames()
	var loaded_token := session._day.state.run_token
	scene._leave("title")
	scene.title_menu.new_requested.emit()
	check(session._day.state.run_token != loaded_token and session._day.state.current_night_index == 1, "returning to title then starting new resets the run")
	await frames()
	# A cached valid row must never authorize loading changed, invalid bytes.
	var data: Dictionary = JSON.parse_string(before.get_string_from_utf8())
	data.entries["manual/1"].payload.cash += 1
	var file := FileAccess.open(lib.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	scene.storage.open("load")
	check(scene.storage.list.get_node("manual_1").disabled, "changed invalid save is disabled even after earlier caching")
	var active_state := session.read_state()
	scene.storage.pending_key = "manual/1"
	scene.storage._commit()
	check(scene.storage.error_dialog.visible and scene.storage.overlay.visible, "failed loading keeps the error and list visible")
	check(session.read_state() == active_state and not scene.storage._loading, "failed loading leaves gameplay untouched and releases refresh suppression")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lib.path))
	scene.queue_free()
	await frames()
	# A click before the deferred warmup must not hide the game afterwards.
	var immediate = load("res://scenes/start.tscn").instantiate()
	immediate.get_node("Bootstrap").save_path = "user://tests/title_entry_immediate.json"
	root.add_child(immediate)
	immediate.title_menu.new_requested.emit()
	await frames()
	check(immediate._counter_screen.visible and immediate._counter_screen.process_mode == Node.PROCESS_MODE_INHERIT, "immediate click cannot race warmup into hiding the game")
	immediate.queue_free()
	await frames()
	print("TITLE ENTRY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
