extends SceneTree

var room: PrivateRoomView
var checks := 0
var failures := 0
var width := 1280
var folder := "res://docs/qa/bedroom-mirror/"
var model := {"visible": true, "phase": "private_room", "night": 1, "body": "", "lamp": "火稳，色暖。", "haunting": false, "dead": false, "pending": false, "can_sleep": true, "can_finish": false, "error": "", "gu_letter": true, "photo_placed": true}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	room = PrivateRoomView.new()
	room.theme = CounterTheme.build()
	root.add_child(room)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.render(model)
	await frames()
	if "interactive" in OS.get_cmdline_user_args():
		_review_controls()
		root.title = "鬼市当铺 · 镜面效果预览"
		print("MIRROR REVIEW READY")
		return
	create_timer(45).timeout.connect(func() -> void: push_error("MIRROR TEST TIMEOUT"); quit(1))
	var mirror := room._mirror
	var normal := await shot("normal")
	check(mirror is BedroomMirror and mirror.frame.visible, "独立镜子组件和镜框")
	check(not mirror.phenomena.visible and mirror.current_state().mode == &"normal", "默认无异象")
	var surface: Rect2 = mirror.get_node("Glass").get_global_rect()
	var center := Vector2i(surface.get_center())
	var frame_point := Vector2i(mirror.global_position + Vector2(4, 4))
	room.render(_dead_model())
	var dark := await shot("lamp_out")
	check(dark.get_pixelv(center).get_luminance() < normal.get_pixelv(center).get_luminance() * 0.85, "命灯熄灭时倒影实际变暗")
	check(dark.get_pixelv(frame_point) == normal.get_pixelv(frame_point), "熄灯不改变固定镜框")
	check(mirror.hit_target.disabled and not mirror.current_state().lamp_lit, "死亡交互和镜内灯光同步")
	room.render(model)
	mirror.set_state({"mode": "fog", "strength": 0.9})
	var fog := await shot("fog")
	check(fog.get_pixelv(center) != normal.get_pixelv(center), "起雾改变镜内像素")
	var outside := Rect2i(0, int(root.size.y * 0.55), int(root.size.x * 0.6), int(root.size.y * 0.4))
	check(fog.get_region(outside).get_data() == normal.get_region(outside).get_data(), "异象不改变房间其它区域")
	check(fog.get_pixelv(frame_point) == normal.get_pixelv(frame_point), "异象不越过镜框")
	mirror.set_state({"mode": "ripple", "strength": 1.0})
	await shot("ripple")
	check(mirror._surface.get_shader_parameter("ripple") == 1.0 and mirror._surface.get_shader_parameter("fog") == 0.0, "切换异象清理前种效果")
	# Existing art exercises the pluggable texture slot; no new story artwork is implied.
	mirror.set_state({"overlay_texture": BedroomMirror.DEFAULT_REFLECTION, "overlay_opacity": 0.4})
	check(mirror.phenomena.visible and is_equal_approx(mirror.phenomena.modulate.a, 0.4), "独立叠加层接收纹理和透明度")
	mirror.reset()
	check(not mirror.phenomena.visible and mirror.reflection.texture == BedroomMirror.DEFAULT_REFLECTION, "恢复正常清除叠加与替换")
	mirror.set_state({"mode": "delayed", "lamp_lit": false, "delay_seconds": 0.3})
	await create_timer(0.08).timeout
	check(mirror.current_state().lamp_lit, "延迟状态先保留旧倒影")
	mirror.set_state({"lamp_lit": true})
	await create_timer(0.35).timeout
	check(mirror.current_state().lamp_lit and mirror.current_state().mode == &"normal", "新状态取消过期延迟")
	mirror.set_state({"mode": "delayed", "lamp_lit": false, "delay_seconds": 0.15})
	await create_timer(0.25).timeout
	check(not mirror.current_state().lamp_lit, "延迟到期更新倒影")
	mirror.reset()
	var restored := await shot("restored")
	check(restored.get_data() == normal.get_data(), "恢复正常无残影且全图一致")
	var second: BedroomMirror = load("res://ui/room/bedroom_mirror.tscn").instantiate()
	root.add_child(second)
	second.hide()
	mirror.set_state({"mode": "fog", "strength": 0.7})
	check(second.current_state().mode == &"normal" and second.reflection.material != mirror.reflection.material, "多实例不共享变化状态")
	second.queue_free()
	mirror.reset()
	await click(mirror.hit_target)
	check(room._observation.visible and room._body.text.contains("对面墙") and not room._body.text.contains("旧衣"), "实际点击使用校正后的镜面文案")
	room.dismiss_observation()
	room.hide()
	var hidden := model.duplicate()
	hidden.visible = false
	room.render(hidden)
	check(mirror.current_state().mode == &"normal" and mirror._pending.is_empty(), "离开房间清理异象和待执行变化")
	room.render(model)
	_review_controls()
	var controls := root.get_node("MirrorReviewControls")
	await click(controls.get_child(2))
	check(mirror.current_state().mode == &"fog", "预览按钮实际切换起雾")
	await click(controls.get_child(3))
	check(mirror.current_state().mode == &"ripple", "预览按钮实际切换扭曲")
	await click(controls.get_child(4))
	check(mirror.current_state().lamp_lit, "慢半拍按钮先保留镜内灯光")
	await create_timer(1.15).timeout
	check(not mirror.current_state().lamp_lit, "慢半拍按钮在延迟后熄灭倒影")
	await click(controls.get_child(1))
	check(not mirror.current_state().lamp_lit and mirror.current_state().mode == &"normal", "预览灯灭按钮联动")
	await click(controls.get_child(0))
	check(mirror.current_state().lamp_lit and mirror.current_state().mode == &"normal", "预览正常按钮恢复")
	await shot("preview")
	print("BEDROOM MIRROR UI: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _dead_model() -> Dictionary:
	var dead := model.duplicate()
	dead.dead = true
	dead.phase = "dead"
	dead.can_sleep = false
	dead.body = "灯盏冷了。"
	return dead

func _review_controls() -> void:
	var panel := HBoxContainer.new()
	panel.name = "MirrorReviewControls"
	panel.position = Vector2(width * 0.25, 20)
	panel.add_theme_constant_override("separation", 8)
	root.add_child(panel)
	for entry in [["正常", "normal"], ["灯灭", "dark"], ["起雾", "fog"], ["扭曲", "ripple"], ["慢半拍", "delayed"]]:
		var button := Button.new()
		button.text = entry[0]
		PrivateRoomView.style_action(button)
		button.custom_minimum_size = Vector2(86, 38)
		panel.add_child(button)
		button.pressed.connect(func() -> void:
			room.render(model)
			room.dismiss_observation()
			if entry[1] == "dark": room.render(_dead_model()); room.dismiss_observation()
			elif entry[1] == "delayed":
				room._state_material.set_shader_parameter("lamp_dead", true)
				room._mirror.set_state({"mode": "delayed", "lamp_lit": false, "delay_seconds": 1.0})
			else: room._mirror.set_state({"mode": entry[1], "strength": 0.85})
		)
	# This preview contains no live RunSession; use 试玩寝屋.cmd for gameplay.
	room._bed.hide()
	room._menu.text = "关闭预览"
	room.menu_requested.connect(func() -> void: quit())

func frames() -> void:
	for n in 4: await process_frame

func click(button: Button) -> void:
	await frames()
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await frames()

func shot(label: String) -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	check(result.save_png(folder + "%d_%s.png" % [width, label]) == OK, "保存实际画面：" + label)
	return result

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
