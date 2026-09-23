class_name WatchDeskView
extends LuxuryAppraisalView

signal judgment_confirmed

var canvas: Control
var object_plate: FanDeskObject
var reference_plate: TextureRect
var helper: Label
var clock_note: Label
var hand_note: Label
var observation: Label
var listen_button: Button
var wind_button: Button
var flat_button: Button
var vertical_button: Button
var open_button: Button
var exterior_button: Button
var note_button: Button
var mark_button: Button
var clear_button: Button
var seek: HSlider
var audio_player: AudioStreamPlayer
var current_clip := ""
var ticks := PackedFloat32Array()
var tick_cursor := 0
var playing := false
var elapsed := 0.0
var pulse: Label
var pulse_toggle: CheckButton
var note_panel: Panel
var id_choice: OptionButton
var repair_choice: OptionButton
var running_choice: OptionButton
var seal_button: Button
var note_reason: Label
var zoom_panel: Panel
var zoom_image: TextureRect
var zoom_reference: TextureRect
var inspection_text := "点按夹板或机芯座，放大核对。"
var showing_movement := false
var sound_volume: HSlider
var clip_label: Label

static func create(owner_view: Control, current: RunSession, id: String) -> WatchDeskView:
	var existing := owner_view.get_tree().root.get_node_or_null("WatchDeskOverlay") as WatchDeskView
	if existing != null: return existing
	var view := WatchDeskView.new(); view.name = "WatchDeskOverlay"; view.session = current; view.item_id = id
	var counter: Node = owner_view
	while counter != null:
		if counter.has_method("_close_drawer"):
			view.judgment_confirmed.connect(Callable(counter,"_close_drawer")); break
		counter = counter.get_parent()
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	if WatchMovementPatterns.enabled(session.definition): inspection_text = "点按刻字、齿轮或机芯座，放大核对。"
	layer = 90
	_root = Control.new(); add_child(_root); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("100e0c"); _root.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.theme = CounterTheme.build(); canvas.size = Vector2(1600,900); _root.add_child(canvas)
	texture(load("res://assets/watch_desk/workbench.png"),Rect2(0,0,1600,900))
	label("鬼市当铺 · 图谱对证",Rect2(42,32,600,52),34)
	clock_note = label("",Rect2(44,90,700,32),21)
	button("返回柜台",Rect2(1380,36,175,48),queue_free,"close")
	label("百达翡丽猎壳金怀表",Rect2(835,160,700,48),31)
	label("钟表图录",Rect2(70,170,620,40),29,true)
	label("先上弦，再换姿态听音。壳款与机芯，分别核对。",Rect2(70,215,665,64),21,true)
	var dial_reference := texture(WatchArt.reference_cell(0),Rect2(70,278,310,310)); dial_reference.material = WatchArt.reference_material()
	reference_plate = texture(WatchArt.reference_cell(1),Rect2(430,278,310,310))
	reference_plate.material = WatchArt.reference_material()
	object_plate = FanDeskObject.new(); object_plate.name = "watch_object"; object_plate.side = "watch"
	object_plate.position = Vector2(915,254); object_plate.size = Vector2(540,540); object_plate.limits = Rect2(object_plate.position,object_plate.size)
	object_plate.material = WatchArt.material(); canvas.add_child(object_plate)
	object_plate.selected.connect(inspect); object_plate.detail_requested.connect(inspect_zoom)
	observation = label("图录所绘：弧形夹板，机芯贴合座圈。",Rect2(70,625,620,55),20,true)
	helper = label("",Rect2(850,658,655,45),21)
	wind_button = button("上弦",Rect2(805,721,140,57),act.bind({"op":"wind"}),"wind")
	flat_button = button("平放",Rect2(956,721,140,57),act.bind({"op":"pose","pose":"flat"}),"flat")
	vertical_button = button("竖放",Rect2(1107,721,140,57),act.bind({"op":"pose","pose":"vertical"}),"vertical")
	listen_button = button("凝神听音",Rect2(1260,710,270,74),listen,"listen",true)
	open_button = button("开盖核对",Rect2(805,796,170,52),open_case,"open_case")
	exterior_button = button("外观 · 5分钟",Rect2(990,796,225,52),exterior,"exterior")
	note_button = button("记下判断",Rect2(1260,796,270,52),show_notes,"notes")
	hand_note = label("",Rect2(140,755,395,80),21,true)
	# Compact playback controls live on the reference page, not across the object.
	seek = HSlider.new(); seek.name = "audio_mark_time"; seek.min_value = 0; seek.max_value = WatchAppraisal.LENGTH; seek.step = .1
	seek.position = Vector2(80,546); seek.size = Vector2(425,30); canvas.add_child(seek)
	clip_label = label("听音进度" if WatchEconomy.enabled(session.definition) else "听过一段后，可拖动标记疑点。",Rect2(80,510,650,30),18,true)
	seek.value_changed.connect(func(value: float) -> void:
		if not current_clip.is_empty(): clip_label.text = ("上弦后" if current_clip.begins_with("wound/") else "上弦前")+" · "+("平放" if current_clip.ends_with("flat") else "竖放")+" · %.1f秒" % value)
	if not WatchEconomy.enabled(session.definition):
		mark_button = button("标记此处",Rect2(545,543,185,38),mark,"mark")
		clear_button = button("清除标记",Rect2(545,586,185,34),clear_marks,"clear_marks")
	pulse_toggle = CheckButton.new(); pulse_toggle.text = "节拍辅助"; pulse_toggle.position = Vector2(75,580); pulse_toggle.size = Vector2(195,36); canvas.add_child(pulse_toggle)
	pulse = label("",Rect2(290,584,245,38),21,true)
	label("听音音量",Rect2(805,859,110,28),18)
	sound_volume = HSlider.new(); sound_volume.min_value = -24; sound_volume.max_value = 0; sound_volume.value = -6; sound_volume.position = Vector2(920,864); sound_volume.size = Vector2(160,20); canvas.add_child(sound_volume)
	sound_volume.value_changed.connect(func(value: float) -> void: audio_player.volume_db = value)
	label("右键放大 · 复听不耗时",Rect2(1120,857,420,30),18)
	audio_player = AudioStreamPlayer.new(); audio_player.volume_db = -6; add_child(audio_player); audio_player.finished.connect(finish_listen)
	build_notes(); build_zoom()
	session.changed.connect(refresh); session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas); layout_canvas(); refresh()

func layout_canvas() -> void:
	var factor := minf(_root.size.x/1600.0,_root.size.y/900.0)
	canvas.scale = Vector2.ONE*factor; canvas.position = (_root.size-Vector2(1600,900)*factor)/2

func label(value: String, rect: Rect2, font: int, ink := false) -> Label:
	var result := Label.new(); result.text = value; result.position = rect.position; result.size = rect.size
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_color_override("font_color",Color("392919") if ink else Color("f1ddb2"))
	result.add_theme_font_override("font",CounterTheme.display_font()); result.add_theme_font_size_override("font_size",font)
	if not ink:
		result.add_theme_color_override("font_shadow_color",Color("160d07")); result.add_theme_constant_override("shadow_offset_x",1); result.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(result); return result

func texture(value: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new(); result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture = value; result.position = rect.position; result.size = rect.size
	result.stretch_mode = TextureRect.STRETCH_SCALE; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(result); return result

func button(value: String, rect: Rect2, action: Callable, key_name: String, primary := false) -> Button:
	var result := Button.new(); result.name = key_name; result.text = value; result.position = rect.position; result.size = rect.size
	result.add_theme_font_override("font",CounterTheme.display_font()); result.add_theme_font_size_override("font_size",24 if primary else 22)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxTexture.new(); style.texture = WatchArt.plaque(primary)
		style.modulate_color = Color.WHITE
		if state == "hover": style.modulate_color = style.modulate_color.lightened(.2)
		if state == "disabled": style.modulate_color = Color("655f55")
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			style.set_texture_margin(side,0); style.set_content_margin(side,5)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		result.add_theme_stylebox_override(state,style)
		result.add_theme_color_override("font_color" if state == "normal" else "font_"+state+"_color",Color("f4e0b9") if state != "disabled" else Color("aca18b"))
	result.pressed.connect(action); canvas.add_child(result); return result

func item() -> ItemInstance:
	return LuxuryAppraisalService.target(session._day,item_id)

func data() -> Dictionary:
	return WatchAppraisal.row(session._day.state,item_id)

func act(payload: Dictionary) -> bool:
	var result := session.fan_command("luxury_watch",item_id,JSON.stringify(payload))
	_error = "" if result.ok else result.message
	refresh()
	return result.ok

func open_case() -> void:
	act({"op":"open"}); showing_movement = data().get("opened",false); refresh()

func exterior() -> void:
	var result := session.fan_command("luxury_exterior",item_id)
	_error = "" if result.ok else result.message; showing_movement = false; refresh()

func inspect(_side: String, point: Vector2) -> void:
	if not showing_movement or playing: return
	act({"op":"inspect","point":[point.x,point.y]})
	var findings := WatchAppraisal.observations(session._day.state,item())
	inspection_text = String(findings.back()) if not findings.is_empty() else "沿夹板边缘与机芯外圈，再挪一挪放大镜。"
	refresh()

func inspect_zoom(_side: String, point: Vector2) -> void:
	if playing: return
	if showing_movement: inspect(_side,point)
	zoom_image.texture = crop(object_plate.texture,point)
	zoom_reference.texture = crop(WatchArt.reference_cell(1),point)
	zoom_panel.show()

func crop(source: Texture2D, point: Vector2) -> AtlasTexture:
	var result := AtlasTexture.new(); result.atlas = source
	var dimensions := source.get_size(); var size := dimensions*.50
	result.region = Rect2((point*dimensions-size/2).clamp(Vector2.ZERO,dimensions-size),size)
	return result

func listen() -> void:
	if data().is_empty():
		var result := session.fan_command("luxury_begin",item_id,"2")
		_error = "" if result.ok else result.message; refresh(); return
	if playing:
		audio_player.stop(); playing = false; refresh(); return
	current_clip = WatchAppraisal.key(data()); elapsed = 0; tick_cursor = 0; seek.value = 0
	if WatchNegotiation.enabled(session.definition) and not act({"op":"listen_start","clip":current_clip}): return
	ticks = WatchAppraisal.ticks(session._day.state,item(),current_clip)
	audio_player.stream = WatchSound.stream(ticks); playing = true; audio_player.play(); refresh()

func finish_listen() -> void:
	playing = false; elapsed = WatchAppraisal.LENGTH; seek.value = elapsed
	if WatchNegotiation.enabled(session.definition): refresh()
	else: act({"op":"listen","clip":current_clip})

func _process(delta: float) -> void:
	if not playing: return
	elapsed = minf(WatchAppraisal.LENGTH,elapsed+delta); seek.value = elapsed
	while tick_cursor < ticks.size() and ticks[tick_cursor] <= elapsed: tick_cursor += 1
	var last := ticks[tick_cursor-1] if tick_cursor > 0 else -10.0
	pulse.text = ("嗒" if elapsed-last < .11 else "") if pulse_toggle.button_pressed else ""
	helper.text = "正在听音 · %.1f / 8秒" % elapsed

func mark() -> void:
	act({"op":"mark","clip":current_clip,"time":seek.value})

func clear_marks() -> void:
	act({"op":"clear_marks","clip":current_clip})

func refresh() -> void:
	if canvas == null: return
	var current := item()
	if current == null: queue_free(); return
	var row := data()
	var state := session._day.state
	var stage := TieredAppraisal.stage(state,item_id,2)
	var sealed: bool = stage.get("committed",false)
	var visitor := CustomerManager.new().active(state)
	clock_note.text = TimeController.clock_text(session.definition.opening_minute,state.game_minutes)
	if visitor != null and visitor.item == current: clock_note.text += " · 客人等到 "+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	var checked: bool = TieredAppraisal.record(state,item_id).get("exterior",false)
	var art_index: int = {"intact":0,"minor":3,"major":4}[current.goods.precision.damage] if checked else 0
	object_plate.texture = WatchArt.movement(current) if showing_movement else WatchArt.cell(art_index); object_plate.queue_redraw()
	wind_button.text = "已上弦" if row.get("wound",false) else "上弦"
	wind_button.disabled = playing or row.get("wound",false)
	flat_button.text = "平放 · 当前" if row.get("pose","flat") == "flat" else "平放"
	vertical_button.text = "竖放 · 当前" if row.get("pose","flat") == "vertical" else "竖放"
	for b in [flat_button,vertical_button,open_button,exterior_button,note_button]: b.disabled = playing
	var heard: Array = row.get("started",[]) if WatchNegotiation.enabled(session.definition) else row.get("listened",[])
	listen_button.text = "停止听音" if playing else "再听一次" if WatchAppraisal.key(row) in heard else "凝神听音"
	exterior_button.text = "复看外观" if checked else "外观 · 5分钟"
	exterior_button.tooltip_text = TieredAppraisal.reason(session._day,"luxury_exterior",item_id,"")
	exterior_button.disabled = playing or not exterior_button.tooltip_text.is_empty()
	open_button.text = "查看机芯" if row.get("opened",false) else "开盖核对"
	note_button.text = "复看手记" if sealed else "记下判断"
	if mark_button != null:
		mark_button.disabled = playing or sealed or current_clip not in row.get("listened",[])
		clear_button.disabled = mark_button.disabled
	seek.editable = not playing and not WatchEconomy.enabled(session.definition)
	var findings := WatchAppraisal.observations(state,current)
	observation.text = inspection_text if showing_movement else "图录所绘：弧形夹板，机芯贴合座圈。"
	if not showing_movement and checked: observation.text = TieredAppraisal.exterior_text(state,current)
	helper.text = _error if not _error.is_empty() else "机芯核对 · 点按细节，右键放大" if showing_movement else "换个姿态，再听一次。"
	var marks: Array = row.get("marks",{}).get(current_clip,[])
	hand_note.text = "手记 · 已落笔" if sealed else "手记 · 平放%s / 竖放%s" % ["已听" if "wound/flat" in row.get("listened",[]) else "未听","已听" if "wound/vertical" in row.get("listened",[]) else "未听"]
	hand_note.text += "\n"+("本段标记："+", ".join(marks.map(func(v: Variant) -> String: return "%.1f秒" % v)) if not WatchEconomy.enabled(session.definition) and not marks.is_empty() else "机芯已有 %d 处观察" % findings.size())
	if WatchNegotiation.enabled(session.definition):
		hand_note.text = ("手记 · 已落笔" if sealed else "手记 · 平放%s / 竖放%s" % ["已试听" if "wound/flat" in heard or "arrival/flat" in heard else "未试听","已试听" if "wound/vertical" in heard or "arrival/vertical" in heard else "未试听"])+"\n机芯已有 %d 处观察" % findings.size()
	if note_panel.visible: refresh_notes()
	if row.is_empty():
		for b in [wind_button,flat_button,vertical_button,open_button,note_button]: b.disabled = true
		listen_button.text = "器材鉴定 · 10分钟"
		var why := TieredAppraisal.reason(session._day,"luxury_begin",item_id,"2")
		listen_button.disabled = not why.is_empty(); helper.text = why

func build_notes() -> void:
	note_panel = Panel.new(); note_panel.name = "watch_notes"; note_panel.position = Vector2(325,170); note_panel.size = Vector2(950,550)
	note_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(note_panel)
	var heading := Label.new(); heading.text = "验表手记"; heading.position = Vector2(36,28); heading.add_theme_font_size_override("font_size",30); note_panel.add_child(heading)
	var names := ["身份","修配","运转"]
	for i in 3:
		var name_label := Label.new(); name_label.text = names[i]; name_label.position = Vector2(40,100+i*85); note_panel.add_child(name_label)
		var choice := OptionButton.new(); choice.position = Vector2(170,88+i*85); choice.size = Vector2(720,56); choice.add_theme_font_size_override("font_size",24); note_panel.add_child(choice)
		var entries: Array = ["暂难定论","与声称表款相符","仿制或冒名"] if i == 0 else ["暂难定论","未见修配","有修补或替换"] if i == 1 else WatchAppraisal.running_labels(session._day.state,item()).values()
		if i == 0 and WatchEconomy.enabled(session.definition): entries[1] = "原厂真品"
		for entry in entries: choice.add_item(entry)
		choice.item_selected.connect(save_draft)
		if i == 0: id_choice = choice
		elif i == 1: repair_choice = choice
		else: running_choice = choice
	note_reason = Label.new(); note_reason.position = Vector2(40,355); note_reason.size = Vector2(865,75); note_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note_reason.add_theme_font_size_override("font_size",21); note_panel.add_child(note_reason)
	seal_button = button("确认落笔",Rect2(955,622,260,60),seal,"seal",true); seal_button.reparent(note_panel); seal_button.position = Vector2(630,450)
	var close := button("继续查验",Rect2(365,622,240,60),note_panel.hide,"close_notes"); close.reparent(note_panel); close.position = Vector2(40,450)
	note_panel.hide()

func show_notes() -> void:
	note_panel.show(); refresh_notes()

func refresh_notes() -> void:
	var stage := TieredAppraisal.stage(session._day.state,item_id,2)
	id_choice.select(["unsure","original","imitation"].find(stage.get("identity","unsure")))
	repair_choice.select(["unsure","intact","altered"].find(stage.get("condition","unsure")))
	running_choice.select(WatchAppraisal.RUNNING.keys().find(data().get("running","unsure")))
	for choice in [id_choice,repair_choice,running_choice]: choice.disabled = stage.get("committed",false)
	if WatchEconomy.enabled(session.definition):
		var visit := CustomerManager.new().active(session._day.state)
		if visit != null and visit.item.instance_id == item_id:
			var used: Array = WatchEconomy.owner(session._day.state,visit).used
			if "identity" in used: id_choice.disabled = true; repair_choice.disabled = true
			if "running" in used: running_choice.disabled = true
	var why := WatchAppraisal.reason(session._day,"luxury_watch",item_id,JSON.stringify({"op":"seal"}))
	seal_button.disabled = not why.is_empty()
	note_reason.text = "手记已落笔。这里只记你的判断；举证谈价请回柜台。" if stage.get("committed",false) else why if not why.is_empty() else "身份、修配与声音须分开判断。落笔后不能改写。"
	if WatchEconomy.enabled(session.definition) and not stage.get("committed",false):
		note_reason.text = why if not why.is_empty() else "未查完也可落笔，拿不准的保留暂难定论。落笔后不能改写。\n举证谈价仍需足够的查验依据。"
	if WatchNegotiation.enabled(session.definition) and not stage.get("committed",false):
		note_reason.text = why if not why.is_empty() else "未查完也可落笔，拿不准的保留暂难定论。落笔后不能改写。\n回柜台可另选对客说法，查验越充分，越有说服依据。"
	if not _error.is_empty(): note_reason.text = _error

func save_draft(_index: int) -> void:
	act({"op":"draft","identity":["unsure","original","imitation"][id_choice.selected],"condition":["unsure","intact","altered"][repair_choice.selected],"running":WatchAppraisal.RUNNING.keys()[running_choice.selected]})

func seal() -> void:
	if act({"op":"seal"}) and WatchEconomy.enabled(session.definition):
		judgment_confirmed.emit()
		queue_free()
	else: refresh_notes()

func build_zoom() -> void:
	zoom_panel = Panel.new(); zoom_panel.position = Vector2(50,135); zoom_panel.size = Vector2(1500,620); zoom_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(zoom_panel)
	for i in 2:
		var picture := TextureRect.new(); picture.position = Vector2(55+i*710,70); picture.size = Vector2(670,460); picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.material = WatchArt.reference_material() if i == 0 else WatchArt.material(); zoom_panel.add_child(picture)
		if i == 0: zoom_reference = picture
		else: zoom_image = picture
	var close := button("收起放大 · Esc",Rect2(1200,155,280,50),zoom_panel.hide,"close_zoom"); close.reparent(zoom_panel); close.position = Vector2(1150,15)
	zoom_panel.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if zoom_panel.visible: zoom_panel.hide()
		elif note_panel.visible: note_panel.hide()
		else: queue_free()
