class_name CounterView
extends Control

signal story_choice_requested(event_id: String, choice_id: String)
signal bell_requested(mode: String, target_id: String)
signal shop_requested
signal customer_action_requested(panel_id: StringName)
signal item_action_requested(panel_id: StringName)
signal inventory_requested
signal social_requested
signal plaque_requested
signal ledger_requested
signal background_requested
signal context_opened(kind: StringName)

var companion: AqiCompanionView
var story: CounterStoryView
var story_active := false
var _story_actor := false
var _story_contact_shadow: TextureRect
var _first_debt_relic: TextureRect
var _portrait: TextureRect
var _counter_foreground: TextureRect
var _item_image: TextureRect
var _speech: Label
var _speech_panel: PanelContainer
var _customer_hotspot: Button
var _item_hotspot: Button
var _customer_context: PanelContainer
var _item_context: PanelContainer
var _dialogue_action: Button
var _trade_action: Button
var _appraisal_action: Button
var _item_panel_id: StringName = &"appraisal"
var _active_id := ""
var feedback_held := false
var conversation_held := false
var _pending_model: Dictionary = {}
var _arrival: Tween
var bell


func _ready() -> void:
	%CounterMessage.hide()
	bell = preload("res://ui/counter/counter_bell.gd").new()
	bell.name = "CounterBell"
	bell.z_index = 5
	add_child(bell)
	_bounds(bell, 0.70, 0.555, 0.765, 0.725)
	bell.rung.connect(bell_requested.emit)
	var backdrop := _make_hotspot("CounterBackdrop", 0.0, 0.0, 1.0, 1.0, "")
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.mouse_default_cursor_shape = Control.CURSOR_ARROW
	backdrop.pressed.connect(_on_background_pressed)
	backdrop.z_index = 1

	_story_contact_shadow = TextureRect.new()
	_story_contact_shadow.name = "AqiContactShadow"
	_story_contact_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_story_contact_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_story_contact_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_contact_shadow.z_index = 2
	var contact_material := ShaderMaterial.new()
	contact_material.shader = preload("res://ui/art/aqi_contact_shadow.gdshader")
	_story_contact_shadow.material = contact_material
	add_child(_story_contact_shadow)
	_story_contact_shadow.hide()
	_first_debt_relic = TextureRect.new()
	_first_debt_relic.name = "PhoenixOnCounter"
	_first_debt_relic.texture = load("res://assets/first_debt/phoenix.png")
	_first_debt_relic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_first_debt_relic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_first_debt_relic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_first_debt_relic.z_index = 3
	add_child(_first_debt_relic)
	_bounds(_first_debt_relic, 0.35, 0.64, 0.47, 0.82)
	_first_debt_relic.hide()
	_portrait = TextureRect.new()
	_portrait.name = "CustomerPortrait"
	_portrait.unique_name_in_owner = true
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.z_index = 2
	add_child(_portrait)
	_bounds(_portrait, 0.315, 0.027, 0.68, 0.592)
	# Same room painting in front of Sun's full sprite: no anatomy is cropped out.
	var foreground_clip := Control.new()
	foreground_clip.name = "CounterForegroundClip"
	foreground_clip.clip_contents = true
	foreground_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground_clip.z_index = 2
	add_child(foreground_clip)
	foreground_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_counter_foreground = $Room.create_counter_foreground()
	foreground_clip.add_child(_counter_foreground)
	_bounds(_counter_foreground, 0.0, 0.0, 1.0, 1.0 / 0.9)
	_counter_foreground.hide()

	_item_image = TextureRect.new()
	_item_image.name = "CounterItemImage"
	_item_image.unique_name_in_owner = true
	_item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_item_image.z_index = 2
	add_child(_item_image)
	_bounds(_item_image, 0.425, 0.62, 0.595, 0.81)

	var shop_sign := TextureRect.new()
	shop_sign.name = "PawnShopSign"
	shop_sign.texture = preload("res://assets/ui/shop_sign/pawn_hanging.png")
	shop_sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shop_sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_sign.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shop_sign.self_modulate = Color(0.58, 0.58, 0.58)
	shop_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_sign.z_index = 3
	add_child(shop_sign)
	_bounds(shop_sign, 0.004, 0.004, 0.094, 0.195)
	var shop_hotspot := _make_hotspot("ShopSignHotspot", 0.004, 0.004, 0.094, 0.195, "查看营业安排 · 不耗时")
	shop_hotspot.accessibility_name = "营业安排"
	# Tint the physical sign on hover; reserve an outline for keyboard focus.
	for state in ["hover", "pressed"]:
		shop_hotspot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	shop_hotspot.mouse_entered.connect(func() -> void: shop_sign.modulate = Color(1.18, 1.12, 1.02))
	shop_hotspot.mouse_exited.connect(func() -> void: shop_sign.modulate = Color.WHITE)
	shop_hotspot.pressed.connect(shop_requested.emit)
	_customer_hotspot = _make_hotspot("CustomerHotspot", 0.325, 0.025, 0.665, 0.57, "与当前客人交谈或交易 · 不耗时")
	_customer_hotspot.pressed.connect(_toggle_customer_context)
	_item_hotspot = _make_hotspot("ItemHotspot", 0.425, 0.615, 0.595, 0.815, "选择柜台货物 · 不耗时")
	_item_hotspot.pressed.connect(_toggle_item_context)
	var inventory_hotspot := _make_hotspot("InventoryHotspot", 0.02, 0.24, 0.165, 0.62, "查看库存柜 · 不耗时")
	inventory_hotspot.pressed.connect(inventory_requested.emit)
	var ledger_hotspot := _make_hotspot("LedgerHotspot", 0.77, 0.68, 0.905, 0.97, "翻看账本 · 不耗时")
	ledger_hotspot.pressed.connect(ledger_requested.emit)

	var book := _make_hotspot("SocialBookHotspot", .64, .765, .775, .975, "翻看往来簿 · 不耗时")
	book.accessibility_name = "往来簿"
	book.icon = preload("res://assets/social_book/closed_book.png")
	book.expand_icon = true
	book.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book.add_theme_constant_override("icon_max_width", 160)
	book.pressed.connect(social_requested.emit)
	book.hide()
	var plaque := _make_hotspot("MilitaryPlaqueHotspot", .795, .005, .935, .080, "查看军方照应牌 · 不耗时")
	plaque.accessibility_name = "军方照应牌"
	plaque.icon = preload("res://assets/social_v27/military_plaque.png")
	plaque.expand_icon = true
	plaque.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.pressed.connect(plaque_requested.emit)
	plaque.hide()

	_customer_context = _make_context("CustomerContext", 0.40, 0.555, 0.64, 0.645)
	var customer_row := HBoxContainer.new()
	customer_row.add_theme_constant_override("separation", 6)
	_customer_context.add_child(customer_row)
	_dialogue_action = _make_context_button("DialogueContextButton", "对话", &"dialogue")
	_trade_action = _make_context_button("TradeContextButton", "交易", &"trade")
	customer_row.add_child(_dialogue_action)
	customer_row.add_child(_trade_action)

	_item_context = _make_context("ItemContext", 0.595, 0.70, 0.70, 0.79)
	_appraisal_action = _make_context_button("AppraisalContextButton", "鉴定", &"appraisal", false)
	_item_context.add_child(_appraisal_action)

	_speech_panel = PanelContainer.new()
	_speech_panel.name = "CustomerSpeech"
	_speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_panel.z_index = 3
	add_child(_speech_panel)
	_bounds(_speech_panel, 0.17, 0.07, 0.355, 0.27)
	_speech_panel.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_speech_panel.add_child(margin)
	_speech = Label.new()
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.max_lines_visible = 4
	_speech.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speech.add_theme_font_size_override("font_size", 19)
	margin.add_child(_speech)
	companion = AqiCompanionView.new()
	companion.z_index = 6
	add_child(companion)
	companion.opened.connect(func() -> void:
		_customer_context.hide()
		_item_context.hide()
		context_opened.emit(&"companion"))
	story = CounterStoryView.new()
	add_child(story)
	_bounds(story, 0.60, 0.095, 0.98, 0.96)
	story.choice_requested.connect(story_choice_requested.emit)
	story.opened.connect(func() -> void: context_opened.emit(&"customer" if _story_actor else &"item"))
	story.closed.connect(func() -> void: focus_hotspot(&"customer" if _story_actor else &"item"))
	_build_painted_controls()
	move_child(bell, get_child_count() - 1)
	# GUI hit testing follows tree order, not the portrait/dialogue z_index.
	move_child(companion, get_child_count() - 1)
	move_child(story, get_child_count() - 1)



func _build_painted_controls() -> void:
	$CustomerPanel.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	$CustomerPanel.z_index = 3
	for label in [%ShopTitle, %CustomerText, %ItemText, _speech]:
		label.add_theme_font_override("font", CounterTheme.display_font())
	for node in [$CustomerPanel, $CustomerPanel/CustomerMargin, %CustomerText]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_hotspot(name_value: String, left: float, top: float, right: float, bottom: float, tooltip: String) -> Button:
	var button := Button.new()
	button.name = name_value
	button.unique_name_in_owner = true
	button.text = ""
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", CounterTheme.box("00000000", "00000000", 0, 0))
	button.add_theme_stylebox_override("hover", _outline_style("b78345", 2))
	button.add_theme_stylebox_override("pressed", _outline_style("d8ad6d", 3, "33281f44"))
	button.add_theme_stylebox_override("focus", _outline_style("e1bd7c", 3))
	button.z_index = 5
	add_child(button)
	_bounds(button, left, top, right, bottom)
	return button


func _outline_style(edge: String, width: int, fill := "00000000") -> StyleBoxFlat:
	var style := CounterTheme.box(fill, edge, 0, 0)
	style.set_border_width_all(width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _make_context(name_value: String, left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_value
	panel.unique_name_in_owner = true
	panel.visible = false
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.z_index = 10
	add_child(panel)
	_bounds(panel, left, top, right, bottom)
	return panel


func _make_context_button(name_value: String, label: String, panel_id: StringName, customer := true) -> Button:
	var button := Button.new()
	button.name = name_value
	button.unique_name_in_owner = true
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CounterTheme.style_paper_button(button)
	button.add_theme_font_size_override("font_size", 20)
	if customer:
		button.pressed.connect(_on_customer_action.bind(panel_id))
	else:
		button.pressed.connect(_on_item_action.bind(panel_id))
	return button


static func _bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom


func render(model: Dictionary) -> void:
	if feedback_held or conversation_held:
		_pending_model = model
		return
	_bounds(_portrait, 0.315, 0.027, 0.68, 0.592)
	_bounds(_customer_hotspot, 0.325, 0.025, 0.665, 0.57)
	_story_contact_shadow.hide()
	%ItemText.show()
	$CustomerPanel.show()
	_customer_hotspot.tooltip_text = "与当前客人交谈或交易 · 不耗时"
	_item_hotspot.tooltip_text = "选择柜台货物 · 不耗时"
	%CustomerText.text = model.customer
	%ItemText.text = model.item
	%CounterMessage.text = ""
	%CounterMessage.hide()
	_bounds(_first_debt_relic, 0.35, 0.565 if model.has("case_dialogue") else 0.64, 0.47, 0.745 if model.has("case_dialogue") else 0.82)
	_first_debt_relic.visible = model.get("first_debt_relic", false)
	var visual: Dictionary = model.get("visual", {})
	var current_active_id := String(model.get("active_id", ""))
	var arrived: bool = current_active_id != _active_id and not current_active_id.is_empty() and (not model.has("continuous_from") or model.continuous_from != _active_id)
	if current_active_id != _active_id:
		dismiss_contexts()
	_active_id = current_active_id
	var active := not _active_id.is_empty()
	var context_actions: Dictionary = model.get("context_actions", {})
	var customer_actions: Array = context_actions.get("customer", [])
	var item_actions: Array = context_actions.get("item", [])
	_customer_hotspot.visible = active and not customer_actions.is_empty()
	_item_hotspot.visible = active and not item_actions.is_empty()
	_apply_action(_dialogue_action, customer_actions, &"dialogue")
	_apply_action(_trade_action, customer_actions, &"trade")
	_item_panel_id = &"dialogue" if item_actions.any(func(a: Dictionary) -> bool: return a.id == "dialogue") else &"appraisal"
	_apply_action(_appraisal_action, item_actions, _item_panel_id)
	if not _customer_hotspot.visible:
		_customer_context.hide()
	if not _item_hotspot.visible:
		_item_context.hide()

	_portrait.texture = CounterVisualCatalog.portrait(visual.get("portrait_asset", ""), visual.get("customer_id", ""), visual.get("person_id", ""))
	_portrait.material = CounterVisualCatalog.portrait_material(_portrait.texture)
	# Keep Sun behind the painted counter edge, like the other visiting adults.
	var sun_visit := _portrait.texture != null and _portrait.texture.resource_path == CounterVisualCatalog.SUN_PORTRAIT
	_counter_foreground.visible = active and (sun_visit or visual.get("portrait_asset","") == "social.qingbang")
	if sun_visit or visual.get("portrait_asset","") == "social.qingbang":
		var portrait_bounds := CounterVisualCatalog.sun_bounds()
		_bounds(_portrait, portrait_bounds.x, portrait_bounds.y, portrait_bounds.z, portrait_bounds.w)
	elif _portrait.texture != null and _portrait.texture.resource_path == CounterVisualCatalog.NEIGHBOR_PORTRAIT:
		_bounds(_portrait, 0.315, 0.025, 0.68, 0.604)
		(_portrait.material as ShaderMaterial).set_shader_parameter("hand_contact_shadow", true)
	elif _portrait.texture != null and _portrait.texture.resource_path in [CounterVisualCatalog.LU_PORTRAIT, CounterVisualCatalog.LU_ELDERLY_PORTRAIT]:
		# His hands remain on his side, cropped by the painted rear counter edge.
		var hem := 445.0 / 941.0 / 0.9
		_bounds(_portrait, 0.3175, hem - 0.46, 0.6825, hem)
	elif _portrait.texture != null and _portrait.texture.resource_path == CounterVisualCatalog.CHEN_PORTRAIT:
		# Petite adult, on the guest side. Keep the waist behind the rear lip,
		# rather than extending the source's flat crop onto the counter mat.
		var hem := 445.0 / 941.0 / 0.9
		_bounds(_portrait, 0.3175, hem - 0.46 * 0.95, 0.6825, hem + 0.46 * 0.05)
		(_portrait.material as ShaderMaterial).set_shader_parameter("source_bottom", 0.95)
	elif CounterVisualCatalog.is_special_portrait(_portrait.texture):
		var portrait_bounds := CounterVisualCatalog.special_bounds(_portrait.texture)
		_bounds(_portrait, portrait_bounds.x, portrait_bounds.y, portrait_bounds.z, portrait_bounds.w)
		(_portrait.material as ShaderMaterial).set_shader_parameter("source_bottom", CounterVisualCatalog.special_placement(_portrait.texture).y)
	elif CounterVisualCatalog.is_wealthy_portrait(_portrait.texture):
		var portrait_bounds := CounterVisualCatalog.wealthy_bounds()
		_bounds(_portrait, portrait_bounds.x, portrait_bounds.y, portrait_bounds.z, portrait_bounds.w)
	elif CounterVisualCatalog.is_ordinary_portrait(_portrait.texture):
		var portrait_bounds := CounterVisualCatalog.ordinary_bounds(_portrait.texture)
		_bounds(_portrait, portrait_bounds.x, portrait_bounds.y, portrait_bounds.z, portrait_bounds.w)
	else:
		_bounds(_portrait, 0.315, 0.027, 0.68, 0.592)
	_portrait.visible = active and _portrait.texture != null
	_item_image.texture = CounterVisualCatalog.front(visual.get("item_asset", ""), model.appraisal.get("images", []))
	if visual.has("tiered_atlas"): _item_image.texture = TieredArt.cell(visual.tiered_atlas,int(visual.tiered_exterior),0)
	if visual.get("watch_art",false): _item_image.texture = WatchArt.counter(int(visual.tiered_exterior))
	_item_image.material = null if visual.get("watch_art",false) else CounterItemArt.material(_item_image.texture, true)
	if visual.get("bangle_art",false):
		_item_image.texture=BangleArt.exterior(int(visual.tiered_exterior));_item_image.material=BangleArt.cutout()
	if visual.has("gramophone_art"):
		_item_image.texture=GramophoneArt.hero(); _item_image.material=GramophoneArt.counter_material()
	if visual.has("camera_art"):
		_item_image.texture=CameraArt.counter(); _item_image.material=null
	if visual.has("porcelain_art"):
		_item_image.texture=PorcelainArt.counter(visual.porcelain_art); _item_image.material=PorcelainArt.surface("front",String(visual.porcelain_art.damage),true,_item_image.texture)
	_item_image.visible = active and _item_image.texture != null
	var item_bounds := CounterItemArt.counter_bounds(_item_image.texture)
	if visual.has("gramophone_art"): item_bounds=Rect2(.36,.35,.35,.51)
	if visual.has("camera_art"): item_bounds=Rect2(.432,.643,.17,.20)
	if visual.has("porcelain_art"): item_bounds=Rect2(.439,.557,.17,.29)
	# ~50 mm case: the dial fits within a palm; keep the larger interaction target below.
	if visual.get("watch_art",false): item_bounds=Rect2(.482125,.71125,.07475,.0975)
	if visual.get("bangle_art",false): item_bounds=Rect2(.4675,.6525,.085,.125)
	_item_image.stretch_mode = TextureRect.STRETCH_SCALE if CounterItemArt.projects_on_table(_item_image.texture) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item_bounds.size != Vector2.ZERO:
		_bounds(_item_image, item_bounds.position.x, item_bounds.position.y, item_bounds.end.x, item_bounds.end.y)
	else: _bounds(_item_image, 0.425, 0.62, 0.595, 0.81)
	_bounds(_item_hotspot, 0.425, 0.615, 0.595, 0.815)
	if item_bounds.size != Vector2.ZERO:
		# Keep a usable click target for small goods; larger painted goods stay inside it.
		var hit := item_bounds.grow(0.012).merge(Rect2(0.46, 0.66, 0.10, 0.12))
		_bounds(_item_hotspot, hit.position.x, hit.position.y, hit.end.x, hit.end.y)
	var folded_coat: bool = visual.get("item_asset", "") == "social.cotton_coat"
	if folded_coat:
		_bounds(_item_image, 0.40, 0.615, 0.635, 0.90)
		_bounds(_item_hotspot, 0.40, 0.615, 0.635, 0.90)
		_bounds(_item_context, 0.65, 0.70, 0.755, 0.79)
	else:
		_bounds(_item_context, 0.595, 0.70, 0.70, 0.79)
	_speech_panel.visible = active and not visual.is_empty()
	if not visual.is_empty():
		%CustomerText.text = "%s\n%s" % [visual.customer_name, visual.attitude]
		if not String(visual.deadline).is_empty(): %CustomerText.text += "\n最迟留到 " + visual.deadline
		if visual.get("pawn_return", false): %CustomerText.text = visual.customer_name + "\n持票回访 · 等候验票"
		_speech.text = visual.introduction
		if not visual.speech.is_empty():
			_speech.text = visual.speech.back().answer
		_speech.tooltip_text = _speech.text
		if not visual.get("intent", "").is_empty(): _speech.text = visual.intent + "\n" + _speech.text
		%ItemText.text = ("%s\n参考价值 %s\n%s" % [visual.item_name, visual.estimate, visual.condition_note]) if visual.get("condition_enabled", false) else "%s\n已知估值 %s 银元\n已见线索 %d 条" % [visual.item_name, visual.estimate, visual.clues.size()]
		if visual.has("tiered_atlas") and not visual.get("estimate_is_range",false):
			%ItemText.text = "%s\n%s\n已见线索 %d 条" % [visual.item_name,"尚未定值" if visual.estimate == "尚未定值" else "已知货值 %s 银元" % visual.estimate,visual.clues.size()]
		if visual.has("item_status"): %ItemText.text = visual.item_status
	$Room.has_customer = active and _portrait.texture == null
	$Room.has_item = active and _item_image.texture == null and not model.get("itemless", false)
	$Room.queue_redraw()
	if arrived:
		if _arrival != null: _arrival.kill()
		_item_image.offset_top = 0
		_item_image.offset_bottom = 0
		_portrait.modulate.a = 0.0
		_item_image.modulate.a = 0.0
		_arrival = create_tween().set_parallel(true)
		_arrival.tween_property(_portrait, "modulate:a", 1.0, 0.18)
		_arrival.tween_property(_item_image, "modulate:a", 1.0, 0.18)

func render_story(model: Dictionary, state: Dictionary) -> void:
	story_active = not model.is_empty()
	if not story_active:
		story.render({}, "")
		return
	var art: String = model.presentation.get("art", "aqi")
	_counter_foreground.hide()
	_story_actor = art in ["aqi", "bent", "fixed"]
	if _arrival != null: _arrival.kill()
	_customer_context.hide()
	_item_context.hide()
	# The complete resting forearms reach forward onto the counter surface.
	_bounds(_portrait, 0.37, 0.19, 0.625, 0.63)
	_bounds(_story_contact_shadow, 0.37, 0.194, 0.625, 0.634)
	_bounds(_customer_hotspot, 0.385, 0.19, 0.61, 0.62)
	_story_contact_shadow.texture = AqiArt.counter_texture("aqi")
	_story_contact_shadow.visible = _story_actor
	_portrait.texture = AqiArt.counter_texture("aqi") if _story_actor else null
	_portrait.material = AqiArt.counter_material("aqi")
	_portrait.visible = _story_actor
	_portrait.modulate.a = 1.0
	var item_art: String = art
	if art == "aqi": item_art = "fixed" if "aq_helped" in state.narrative_flags else "bent"
	_item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_image.texture = AqiArt.counter_texture(item_art)
	_item_image.material = AqiArt.counter_material(item_art)
	_item_image.visible = true
	_item_image.modulate.a = 1.0
	_bounds(_item_image, 0.425, 0.62, 0.595, 0.81)
	_item_image.offset_top = 0
	_item_image.offset_bottom = 0
	_speech_panel.hide()
	$CustomerPanel.visible = _story_actor
	%CustomerText.text = "阿七" if "aq_name_known" in state.narrative_flags else "柜台边的小女孩"
	%ItemText.text = model.presentation.get("item_label", "纸风车" if _story_actor else ("半张旧铺草图" if art == "plan" else "旧《阴账》"))
	_customer_hotspot.visible = _story_actor
	_customer_hotspot.tooltip_text = "继续交谈 · 不耗时"
	_item_hotspot.visible = true
	_item_hotspot.tooltip_text = "看看风车" if _story_actor else "继续翻看"
	$Room.has_customer = false
	$Room.has_item = false
	$Room.queue_redraw()
	story.render(model, state.run_token + "/" + model.pending_id + "/" + str(state.event_history.size()))

func release_feedback() -> void:
	feedback_held = false
	if conversation_held: return
	if not _pending_model.is_empty():
		var model := _pending_model
		_pending_model = {}
		render(model)

func depart_with_item() -> void:
	if _arrival != null: _arrival.kill()
	_arrival = create_tween().set_parallel(true)
	_arrival.tween_property(_portrait, "modulate:a", 0.0, 0.3)
	_arrival.tween_property(_item_image, "modulate:a", 0.0, 0.3)

func hand_over_item() -> void:
	if _arrival != null: _arrival.kill()
	_arrival = create_tween()
	_arrival.tween_property(_item_image, "position:y", _item_image.position.y + 16, 0.22)
	_arrival.parallel().tween_property(_item_image, "modulate:a", 0.0, 0.22)
	_arrival.tween_interval(0.26)
	_arrival.tween_property(_portrait, "modulate:a", 0.0, 0.18)


func _apply_action(button: Button, actions: Array, action_id: StringName) -> void:
	button.visible = false
	for entry in actions:
		if StringName(entry.get("id", "")) != action_id:
			continue
		button.text = String(entry.get("label", button.text))
		button.disabled = not bool(entry.get("enabled", true))
		button.tooltip_text = String(entry.get("reason", ""))
		button.visible = true
		return


func _toggle_customer_context() -> void:
	if story_active:
		story.show_dialogue()
		return
	if not _customer_hotspot.visible:
		return
	var show_context := not _customer_context.visible
	dismiss_contexts()
	_customer_context.visible = show_context
	if show_context:
		context_opened.emit(&"customer")
		_dialogue_action.call_deferred("grab_focus")


func _toggle_item_context() -> void:
	if story_active:
		story.show_dialogue()
		return
	if not _item_hotspot.visible:
		return
	var show_context := not _item_context.visible
	dismiss_contexts()
	_item_context.visible = show_context
	if show_context:
		context_opened.emit(&"item")
		_appraisal_action.call_deferred("grab_focus")


func _on_customer_action(panel_id: StringName) -> void:
	dismiss_contexts()
	customer_action_requested.emit(panel_id)


func _on_item_action(panel_id: StringName) -> void:
	dismiss_contexts()
	item_action_requested.emit(_item_panel_id if panel_id == &"appraisal" else panel_id)


func _on_background_pressed() -> void:
	dismiss_contexts()
	background_requested.emit()


func dismiss_contexts() -> bool:
	var dismissed := _customer_context.visible or _item_context.visible
	if companion != null and companion.collapse(): dismissed = true
	_customer_context.hide()
	_item_context.hide()
	return dismissed


func focus_hotspot(kind: StringName) -> void:
	var target := get_hotspot(kind)
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func get_hotspot(kind: StringName) -> Button:
	var targets := {
		&"shop": get_node("ShopSignHotspot"),
		&"customer": _customer_hotspot,
		&"companion": companion.hotspot,
		&"item": _item_hotspot,
		&"inventory": get_node("InventoryHotspot"),
		&"ledger": get_node("LedgerHotspot"),
		&"social": get_node("SocialBookHotspot"),
		&"plaque": get_node("MilitaryPlaqueHotspot"),
	}
	return targets.get(kind) as Button


func set_counter_message(message: String) -> void:
	%CounterMessage.text = ""
	%CounterMessage.hide()


func set_atmosphere(mode: int, preview: bool, intrusion: bool, haunting: bool, dead: bool) -> void:
	companion.set_lighting(-1, mode)
	$Room.atmosphere = mode
	bell.atmosphere = mode
	$Room.smoke_wrong = intrusion or (preview and mode == 1)
	$Room.lamp_wrong = haunting or (preview and mode == 2)
	$Room.lamp_dead = dead
	_portrait.modulate = Color([Color.WHITE, Color("9aaba9"), Color("b3c9ce")][mode], _portrait.modulate.a)
	_item_image.modulate = Color([Color.WHITE, Color("b0b9b5"), Color("c1d2d7")][mode], _item_image.modulate.a)
	$Room.queue_redraw()
	%AtmosphereLabel.text = ["灯火初上", "夜深了", "禁时 · 鬼市"][mode]
	if preview:
		%AtmosphereLabel.text = "美术预览 · " + ["正常营业", "深夜异常", "禁时鬼市"][mode]
	%AtmosphereLabel.tooltip_text = "仅切换视觉，不推进时间、不改变规则或存档。" if preview else ""

func set_night_lighting(band: int) -> void:
	if band < 0: return
	companion.set_lighting(band)
	# Only scene sprites dim; appraisal evidence, dialogue and money stay readable.
	_portrait.modulate = Color([Color.WHITE, Color("8e8271"), Color("655f55"), Color("4b4944")][band], _portrait.modulate.a)
	# Aqi sits beside the counter lamp; keep her face readable after closing.
	if story_active and _story_actor and band == 3: _portrait.modulate = Color("8e8271")
	_item_image.modulate = Color([Color.WHITE, Color("ead8b5"), Color("d3c7aa"), Color("b8b09b")][band], _item_image.modulate.a)
	%AtmosphereLabel.text = ["人声尚近", "灯下做买卖", "街外无光", "只剩一盏灯"][band]
