extends "res://tests/bedroom_art_ui_smoke.gd"

var _preview_room: PrivateRoomView
var _live: Dictionary
var _toolbar: HBoxContainer

func _shot_directory() -> String:
	return "res://docs/qa/life-lamp/"

func _review_extra(room: PrivateRoomView) -> void:
	_preview_room = room
	_live = room._model.duplicate(true)
	shot_root = "res://docs/qa/life-lamp/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_root))
	var before := session.read_state()
	for damage in 5:
		_show_lamp(damage)
		room._lamp.release_focus()
		await _pointer(Vector2(width - 35, 100))
		await frames()
		check(room._state_material.get_shader_parameter("personal_damage") == damage, "correct lamp shader state")
		check(is_equal_approx(float(room._mirror.current_state().lamp_light), PersonalRisk.LIGHT[damage]), "mirror light tracks lamp")
		check(room._mirror.current_state().mode == &"normal" and not room._mirror.phenomena.visible, "lamp does not trigger mirror phenomena")
		room.dismiss_observation()
		await shot("lamp_" + str(damage))
		await create_timer(0.45).timeout
		await shot("motion_" + str(damage))
		if damage < 4:
			await click(room._lamp)
			check(room._body.text == PersonalRisk.DESCRIPTIONS[damage], "observation describes actual flame")
			await shot("observe_" + str(damage))
			room.dismiss_observation()
		else: check(room._bed.disabled and room._lamp.disabled, "extinguished preview has no gameplay actions")
	check(before == session.read_state(), "visual preview cannot mutate saves")
	room.render(_live)
	await _pointer(Vector2(width - 35, 100))
	if _keep_open:
		_toolbar = HBoxContainer.new()
		_toolbar.position = Vector2(width - 720, 18)
		_toolbar.add_theme_constant_override("separation", 8)
		root.add_child(_toolbar)
		var label := Label.new()
		label.text = "灯态预览  "
		_toolbar.add_child(label)
		for damage in 5:
			var button := Button.new()
			button.text = ["正常", "轻伤", "中伤", "重伤", "熄灭"][damage]
			button.custom_minimum_size = Vector2(82, 38)
			button.pressed.connect(_show_lamp.bind(damage))
			_toolbar.add_child(button)
		var reset := Button.new()
		reset.text = "返回试玩"
		reset.pressed.connect(func() -> void: _preview_room.render(_live); _toolbar.hide())
		_toolbar.add_child(reset)
		await frames()
		for damage in 5:
			await click(_toolbar.get_child(damage + 1))
			check(int(_preview_room._model.lamp_state.damage) == damage, "preview buttons switch actual native shader")
		await click(_toolbar.get_child(1))
		await _pointer(Vector2(width - 25, 110))
		print("LIFE LAMP PREVIEW READY: five state buttons, isolated saves")
	else: print("LIFE LAMP VISUAL: %d checks, %d failures" % [checks, failures])

func _show_lamp(damage: int) -> void:
	var model := _live.duplicate(true)
	model.lamp_state = {"damage": damage, "light": PersonalRisk.LIGHT[damage]}
	model.lamp = PersonalRisk.DESCRIPTIONS[damage]
	model.dead = damage == 4
	model.phase = "dead" if damage == 4 else "private_room"
	model.haunting = damage > 0
	model.can_sleep = damage < 4
	model.can_finish = false
	model.body = PersonalRisk.DESCRIPTIONS[damage]
	_preview_room.render(model)
