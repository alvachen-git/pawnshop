extends "res://tests/m6_ui_smoke.gd"

class PhaseFailingSave extends SaveManager:
	var fail_phase := ""
	func save_state(state: RunState, definition: RunDefinition, version: int) -> bool:
		if state.phase == fail_phase:
			error_message = "测试注入：磁盘写入失败。"
			return false
		return super.save_state(state, definition, version)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v9.json"
	_main.get_node("Bootstrap").save_path = "user://tests/sleep_transition.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	var helper := RoomTests.new()
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	var room := _main.find_child("PrivateRoom", true, false) as PrivateRoomView
	var save := PhaseFailingSave.new(_session._save.path)
	save.catalog = _session._save.catalog
	_session._save = save
	for failing_phase in ["day_summary", "pre_open"]:
		save.fail_phase = ""
		_session.new_run()
		helper.open(_session)
		helper.seal(_session)
		_check(_session.execute("enter_room").ok, "进入测试寝屋")
		_check(_session.execute("sleep").ok, "进入测试睡眠")
		await _frames()
		var before := _session.read_state()
		save.fail_phase = failing_phase
		await _click("放松入眠")
		if failing_phase == "day_summary":
			_check(_session.read_state() == before, "过夜保存失败完整回滚")
			_check(room.visible and room._body.text.contains("磁盘写入失败"), "过夜失败留在寝屋并显示原因")
			_check(not room._close_observation.disabled, "过夜失败允许重试")
			save.fail_phase = ""
			await _click("放松入眠")
		else:
			_check(_session.read_state().phase == "day_summary" and _session.read_state().current_night_index == 1, "次日保存失败保留已完成的日结")
			_check(room._transition_error != null and room._transition_error.visible, "离开寝屋后仍显示保存失败提示")
			if room._transition_error != null:
				await _click_button(room._transition_error.get_ok_button())
			save.fail_phase = ""
			await _click("进入下一夜")
		_check(_session.read_state().phase == "pre_open" and _session.read_state().current_night_index == 2, "重试只推进到第二夜")
		var recovered := _session.read_state()
		_check(_session.load_checkpoint().ok and _session.read_state() == recovered, "恢复后的次日进度已保存")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	print("SLEEP TRANSITION UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
