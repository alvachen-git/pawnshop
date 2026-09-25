class_name FacilitiesRoomView
extends Control

signal return_requested
signal counter_requested

const LEVEL_NAMES := ["初始 · 旧铺未修", "一级 · 基础整修", "二级 · 专用分区", "三级 · 精品与比对"]
const NUMBERS := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四", "十五", "十六"]
var session: RunSession
var preview_level := -1
var selected := ""
var hotspots: Dictionary = {}
var return_button: Button
var sheet: PanelContainer
var body: Label
var actions: VBoxContainer
var status_note: Label
var stock_picture: TextureRect
var stock_id := ""
var _stage: Control
var _paint: TextureRect
var _shader: ShaderMaterial
var _title: Label
var _scroll: ScrollContainer
var _close: Button
var _hover_label: Label
var _notice: Button
var _materials: Button
var _numbers: Array[Label] = []
var _compartment: TextureRect
var _textures: Array[Texture2D] = []
var _last_error := ""
var _preview_bar: HBoxContainer
var _render_key := ""
var _return_art: TextureRect

func _ready() -> void:
	theme = CounterTheme.build()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for level in 4: _textures.append(load("res://assets/facilities/room-level%d.png" % level))
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.anchor_bottom = 1.0 / 0.9
	_paint = TextureRect.new()
	_paint.texture = _textures[0]
	_paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_paint)
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader = ShaderMaterial.new()
	_shader.shader = preload("res://ui/shop/facilities_room.gdshader")
	_shader.set_shader_parameter("repaired", _textures[1])
	_shader.set_shader_parameter("specialized", _textures[2])
	_paint.material = _shader
	# Numbering is gameplay data, never generated lettering. Sixteen distinct public cabinets.
	for index in 16:
		var number := Label.new()
		number.text = NUMBERS[index]
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font", CounterTheme.display_font())
		number.add_theme_color_override("font_color", Color("251c12"))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(number)
		var cx: float = [0.280, 0.374, 0.624, 0.706][index % 4]
		var cy: float = [0.095, 0.240, 0.385, 0.535][index / 4]
		bounds(number, Rect2(cx - 0.016, cy - 0.023, 0.032, 0.046))
		_numbers.append(number)
	stock_picture = TextureRect.new()
	stock_picture.name = "DisplayedStock"
	stock_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stock_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stock_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(stock_picture)
	bounds(stock_picture, Rect2(0.098, 0.572, 0.095, 0.100))
	stock_picture.hide()
	_compartment = TextureRect.new()
	_compartment.texture = preload("res://assets/facilities/discovered-compartment.png")
	_compartment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_compartment.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_compartment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_material := ShaderMaterial.new()
	key_material.shader = preload("res://ui/art/counter_cutout.gdshader")
	key_material.set_shader_parameter("chroma_key", true)
	_compartment.material = key_material
	_stage.add_child(_compartment)
	bounds(_compartment, Rect2(0.720, 0.456, 0.060, 0.160))
	_compartment.hide()
	_make_hotspot("display", "陈列柜", Rect2(0.015, 0.414, 0.237, 0.445))
	_make_hotspot("archive", "旧账柜", Rect2(0.418, 0.175, 0.156, 0.482))
	_make_hotspot("bench", "鉴物台", Rect2(0.706, 0.564, 0.265, 0.300))
	_make_hotspot("compartment", "检查夹板", Rect2(0.720, 0.467, 0.044, 0.112))
	for topic in ShopKnowledgeService.TOPICS:
		var info: Dictionary = ShopKnowledgeService.topic_info(session.definition if session != null else null,topic)
		var id := "knowledge/" + String(topic)
		_make_hotspot(id, info.name, info.bounds)
		hotspots[id].hide()
	_hover_label = Label.new()
	_style_scene_caption(_hover_label, 21)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hover_label)
	_hover_label.hide()
	var location := Label.new()
	location.name = "RoomLocationCaption"
	location.text = "铺\n内"
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_scene_caption(location, 27)
	location.add_theme_constant_override("line_spacing", 6)
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(location)
	bounds(location, Rect2(0.024, 0.032, 0.034, 0.105))
	return_button = Button.new()
	return_button.name = "FacilitiesReturn"
	return_button.accessibility_name = "返回柜台"
	return_button.pressed.connect(func() -> void: return_requested.emit())
	add_child(return_button)
	bounds(return_button, Rect2(0.916, 0.335, 0.078, 0.12))
	_return_art = navigation_arrow(return_button)
	_notice = Button.new()
	CounterTheme.style_paper_button(_notice)
	_notice.pressed.connect(func() -> void: counter_requested.emit())
	add_child(_notice)
	bounds(_notice, Rect2(0.76, 0.025, 0.225, 0.06))
	_notice.hide()
	_materials = Button.new()
	CounterTheme.style_paper_button(_materials)
	_materials.pressed.connect(select.bind("archive"))
	add_child(_materials)
	bounds(_materials, Rect2(0.40, 0.81, 0.20, 0.07))
	_materials.hide()
	_make_sheet()
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close_sheet()
	)
	visibility_changed.connect(func() -> void:
		if visible: refresh()
		else: _clear_hover()
	)
	resized.connect(_layout)
	_layout()

static func bounds(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _style_scene_caption(label: Label, font_size: int) -> void:
	var font := FontVariation.new()
	font.base_font = CounterTheme.display_font()
	font.variation_embolden = 0.4
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9ddbe"))
	label.add_theme_color_override("font_shadow_color", Color("17120dec"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)

static func navigation_arrow(button: Button, left := false) -> TextureRect:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art := TextureRect.new()
	art.texture = preload("res://assets/facilities/return-arrow.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.flip_h = left
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	art.offset_left = -28
	art.offset_right = 28
	art.offset_top = -19
	art.offset_bottom = 19
	# Fixed small artwork, with the original generous hit area kept invisible.
	var quiet := Color(1.18, 1.12, 0.98, 0.96)
	var highlighted := Color(1.32, 1.23, 1.06, 1.0)
	art.modulate = quiet
	button.mouse_entered.connect(func() -> void: art.modulate = highlighted)
	button.mouse_exited.connect(func() -> void: art.modulate = highlighted if button.has_focus() else quiet)
	button.focus_entered.connect(func() -> void: art.modulate = highlighted)
	button.focus_exited.connect(func() -> void: art.modulate = highlighted if button.is_hovered() else quiet)
	return art

func _make_hotspot(id: String, label: String, rect: Rect2) -> void:
	var button := Button.new()
	button.name = "Facility_" + id
	button.flat = true
	button.accessibility_name = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_stage.add_child(button)
	bounds(button, rect)
	button.pressed.connect(select.bind(id))
	button.mouse_entered.connect(_show_hover.bind(id, label))
	button.mouse_exited.connect(_clear_hover)
	button.focus_entered.connect(_show_hover.bind(id, label))
	button.focus_exited.connect(_clear_hover)
	hotspots[id] = button

func _show_hover(id: String, label: String) -> void:
	if sheet.visible: return
	_clear_hover()
	if id.begins_with("knowledge/"):
		var area: Rect2 = ShopKnowledgeService.topic_info(session.definition if session != null else null,id.trim_prefix("knowledge/")).bounds
		_shader.set_shader_parameter("cabinet_hover", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
		return
	_hover_label.text = label
	_hover_label.size = Vector2(144, 38)
	var rect: Rect2 = hotspots[id].get_global_rect()
	_hover_label.position = Vector2(clampf(rect.get_center().x - global_position.x - 72, 8, size.x - 152), clampf(rect.position.y - global_position.y - 40, 80, size.y - 45))
	_hover_label.show()

func _clear_hover() -> void:
	_hover_label.hide()
	_shader.set_shader_parameter("cabinet_hover", Vector4.ZERO)

func _make_sheet() -> void:
	sheet = PanelContainer.new()
	sheet.name = "FacilityPaper"
	sheet.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	add_child(sheet)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	sheet.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", CounterTheme.display_font())
	_title.add_theme_font_size_override("font_size", 25)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_close = Button.new()
	_close.text = "收起"
	_close.pressed.connect(close_sheet)
	CounterTheme.style_paper_button(_close)
	head.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	content.add_child(body)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	content.add_child(actions)
	status_note = Label.new()
	status_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_note.add_theme_font_size_override("font_size", 17)
	status_note.add_theme_color_override("font_color", Color("842e24"))
	content.add_child(status_note)
	sheet.hide()

func _layout() -> void:
	if sheet == null: return
	var width := clampf(size.x * 0.34, 405, 510)
	var height := minf(size.y * 0.52, 400)
	if selected == "bench" and session != null and FanConditionService.enabled(session.definition): height = minf(height, 260)
	if selected.begins_with("knowledge/"): height = minf(height, 260)
	if session != null and TieredAppraisal.enabled(session.definition) and (selected == "bench" or selected.begins_with("knowledge/")): height = minf(size.y*0.68,580)
	sheet.position = Vector2((size.x - width) * 0.50, size.y - height - 18)
	sheet.size = Vector2(width, height)
	for number in _numbers: number.add_theme_font_size_override("font_size", 17 if size.x < 1450 else 21)

func bind(value: RunSession) -> void:
	session = value
	session.changed.connect(refresh)
	session.restored.connect(func() -> void: _render_key = ""; _last_error = ""; close_sheet(); refresh())
	refresh()

func select(id: String) -> void:
	if id == "knowledge/luxury_textile" and session != null and CameraEconomy.enabled(session.definition):
		close_sheet(); CameraGuideView.open(self,session); return
	if id == "knowledge/luxury_porcelain" and session != null and PorcelainEconomy.enabled(session.definition):
		close_sheet(); PorcelainGuideView.open(self,session); return
	if id == "knowledge/luxury_metal" and session != null and BangleEconomy.enabled(session.definition):
		close_sheet(); BangleGuideView.open(self,session); return
	if id == "knowledge/luxury_jade" and session != null and PearlEconomy.enabled(session.definition):
		close_sheet(); PearlGuideView.open(self,session); return
	if id == "knowledge/luxury_watch" and session != null and WatchEconomy.enabled(session.definition):
		close_sheet(); WatchGuideView.open(self,session); return
	_clear_hover()
	selected = "archive" if id == "compartment" else id
	_last_error = ""
	_render_key = ""
	_hover_label.hide()
	sheet.show()
	refresh()
	_scroll.scroll_vertical = 0
	_close.grab_focus()

func close_sheet() -> void:
	if sheet == null: return
	sheet.hide()
	_hover_label.hide()
	if hotspots.has(selected): hotspots[selected].grab_focus()
	selected = ""
	_render_key = ""

func refresh() -> void:
	if _paint == null: return
	if not is_visible_in_tree(): return
	for topic in ShopKnowledgeService.TOPICS:
		var active := preview_level < 0 and session != null and ShopKnowledgeService.enabled(session.definition)
		if session != null: bounds(hotspots["knowledge/"+String(topic)],ShopKnowledgeService.topic_info(session.definition,topic).bounds)
		hotspots["knowledge/" + String(topic)].visible = active and (not String(topic).begins_with("luxury_") or WealthyCustomers.active(session._day.state))
	if preview_level >= 0:
		_paint.texture = _textures[preview_level]
		_shader.set_shader_parameter("full_plate", true)
		_shader.set_shader_parameter("late_amount", 0.0)
		stock_picture.hide()
		_compartment.hide()
		hotspots.compartment.hide()
		_notice.hide()
		_materials.hide()
		if sheet.visible: _render_preview()
		return
	if session == null or not session._day.state.shop_growth_enabled: return
	var state := session._day.state
	var growth := state.shop_growth
	_shader.set_shader_parameter("full_plate", false)
	_shader.set_shader_parameter("bench_specialized", FanAppraisalService.bench_level(state) >= 2)
	_shader.set_shader_parameter("specialized", _textures[3] if FanAppraisalService.bench_level(state) >= 3 else _textures[2])
	_shader.set_shader_parameter("bench_built", bool(growth.bench))
	_shader.set_shader_parameter("display_built", bool(growth.display))
	_shader.set_shader_parameter("late_amount", clampf((float(state.game_minutes) - 180.0) / 300.0, 0.0, 0.65) if state.phase != &"pre_open" else 0.0)
	_paint.texture = _textures[0]
	stock_id = String(growth.display_id)
	var item := InventoryManager.new().find(state, stock_id)
	stock_picture.visible = item != null and ShopGrowthService.item_reason(state, item).is_empty()
	if stock_picture.visible:
		var definition := state.ghost_catalog.get_definition("items", item.definition_id) as ItemDefinition
		stock_picture.texture = CounterVisualCatalog.front(definition.visual_asset_id)
		stock_picture.tooltip_text = definition.display_name
	var count: int = growth.exploration.size()
	_compartment.visible = count == 3
	hotspots.compartment.visible = count >= 2
	_materials.visible = count > 0
	_materials.text = ["", "查看旧柜目录", "查看柜号记录", "复看柜格记录"][count]
	var model := session.counter_model()
	_notice.visible = state.phase == &"open" and not String(model.active_id).is_empty()
	_notice.text = "柜前有客 · 回去接待"
	if not sheet.visible: return
	var key := selected + JSON.stringify(growth) + "/%s/%s/%s/%s" % [state.phase, state.game_minutes, state.cash, PreparationService.count(state)] + _last_error
	if key == _render_key: return
	_render_key = key
	_clear_actions()
	status_note.text = _last_error
	var direct_bench := selected == "bench" and FanConditionService.enabled(session.definition)
	actions.get_parent().move_child(actions, 0 if selected.begins_with("knowledge/") else 1)
	if selected == "bench":
		_title.text = "鉴物台 · " + ("一级" if growth.bench else "待整修")
		body.text = "台面已整平，灯座牢靠，常用工具收在盘里。\n\n普通货用放大镜、灯或磁铁进行的10分钟检查，缩至5分钟。原5分钟检查不变。" if growth.bench else "旧毡起皱，灯座有些松动。\n\n整修后，普通工具检查由10分钟缩至5分钟。\n40银元 · 准备1次 · 当晚可用。"
		if direct_bench and not growth.bench: _action("整修鉴物台 · 40银元 / 准备1次", "build", "bench")
		if FanAppraisalService.enabled(session.definition):
			var advanced := FanAppraisalModels.facility(session._day)
			_title.text = advanced.title
			body.text = advanced.body if direct_bench else body.text + "\n\n" + advanced.body
			for row in advanced.buttons: _action(row.label, row.command, row.detail)
		if not growth.bench and not direct_bench: _action("整修鉴物台 · 40银元 / 准备1次", "build", "bench")
		if WealthyCustomers.active(state):
			body.text += "\n器材与知识齐备后，可查验高档货。" if TieredAppraisal.enabled(session.definition) else "\n高档货细查须二级台；图录对证还需学习对应知识。"
			var targets: Array = state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state in ["owned", "pledged"] and WealthyCustomers.is_item(i.definition_id))
			var visitor := CustomerManager.new().active(state)
			if visitor != null and visitor.purpose.is_empty() and WealthyCustomers.is_item(visitor.item.definition_id): targets.push_front(visitor.item)
			for target in targets:
				_action("对证 · " + (state.ghost_catalog.get_definition("items", target.definition_id) as ItemDefinition).display_name, "luxury_open", target.instance_id)
	elif selected == "display":
		_title.text = "陈列柜 · " + ("一级" if growth.display else "待整修")
		if not growth.display:
			body.text = "玻璃蒙着灰，柜门合不拢。\n\n修好后，可陈列一件自有普通现货，等识货的客人来问价。\n60银元 · 准备1次 · 当晚可用。"
			_action("整修陈列柜 · 60银元 / 准备1次", "build", "display")
		else:
			var page := ShopGrowthReadModels.page(session._day, 1)
			body.text = "陈列 %d/1\n" % (1 if stock_picture.visible else 0) + (stock_picture.tooltip_text if stock_picture.visible else "柜位空着。") + "\n\n开铺后，可能引来问价的客人；买卖须回柜台亲自办理。\n开铺前可选换，营业中可撤下。"
			for row in page.buttons: _action(row.label, row.command, row.detail)
	elif selected == "archive":
		_title.text = "旧账柜"
		var page := ShopGrowthReadModels.page(session._day, 2)
		body.text = page.body.trim_prefix("沿柜查铺\n\n")
		for row in page.buttons: _action(row.label, row.command, row.detail)
		if WealthyCustomers.active(state):
			for topic in ShopKnowledgeService.TOPICS:
				if String(topic).begins_with("luxury_") and not ShopKnowledgeService.mastered(state, topic): _action("学习" + ShopKnowledgeService.TOPICS[topic].name + " · 准备1次", "learn_knowledge", topic)
	elif selected.begins_with("knowledge/"):
		var page := ShopKnowledgeService.page(session._day, selected.trim_prefix("knowledge/"))
		_title.text = page.title
		body.text = page.body
		for row in page.buttons: _action(row.label, row.command, row.detail)
	_layout()

func _clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()

func _action(label: String, command: String, detail: String) -> void:
	var reason := "" if command == "luxury_open" else ShopGrowthService.reason(session._day, command, detail)
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 48
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason
	CounterTheme.style_paper_button(button)
	button.pressed.connect(func() -> void:
		if command == "luxury_open":
			LuxuryAppraisalView.open(self, session, detail)
			return
		# The shared session is the only writer; no optimistic cash/art or save mutation.
		var result := session.growth_command(command, detail)
		_last_error = "" if result.ok else result.message
		_render_key = ""
		refresh()
		_scroll.set_deferred("scroll_vertical", 0)
	)
	actions.add_child(button)
	if not reason.is_empty():
		var hint := Label.new()
		hint.text = reason
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 16)
		actions.add_child(hint)

func set_preview(level: int) -> void:
	preview_level = clampi(level, 0, 3)
	close_sheet()
	refresh()
	if _preview_bar != null:
		for index in _preview_bar.get_child_count():
			(_preview_bar.get_child(index) as Button).button_pressed = index == preview_level

func add_preview_controls() -> void:
	_preview_bar = HBoxContainer.new()
	_preview_bar.add_theme_constant_override("separation", 8)
	add_child(_preview_bar)
	bounds(_preview_bar, Rect2(0.22, 0.026, 0.71, 0.064))
	for level in 4:
		var button := Button.new()
		button.text = LEVEL_NAMES[level]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CounterTheme.style_paper_button(button)
		button.pressed.connect(set_preview.bind(level))
		_preview_bar.add_child(button)
	return_button.hide()
	set_preview(0)

func _render_preview() -> void:
	_clear_actions()
	status_note.text = "独立美术预览，不改经营进度。"
	_title.text = {"bench": "鉴物台", "display": "陈列柜", "archive": "旧账柜"}.get(selected, "设施") + " · " + LEVEL_NAMES[preview_level].split(" · ")[0]
	var descriptions := {
		"bench": ["破毡与松动的灯座；基础工具仍可用。", "台面稳固，常用工具归盘。\n对应普通检查10→5分钟。", "专用台面、工具分区与图录架。\n工具组和知识需分别取得。", "扩展比对台面、固定装置与资料抽屉。\n用于并置实物及复杂比对。"],
		"display": ["旧框松动、玻璃蒙尘，尚不能陈列。", "修好旧柜，提供1个陈列位置。", "定制新柜框、完整漆面与统一铜件，规划2个位置。", "精细木作、衬垫和资料展示，规划3个位置。"],
		"archive": ["柜体残旧、账册杂乱。", "补齐木条，校正柜门，保留修补痕迹。", "木料统一，漆面整洁，柜体收纳规整。", "细木漆面、精工收边与完整资料收纳。"]
	}
	body.text = descriptions.get(selected, descriptions.archive)[preview_level]
	if selected == "archive": body.text += "\n\n柜体修缮与查账线索分开。取得外观等级的方式尚待定稿。"
