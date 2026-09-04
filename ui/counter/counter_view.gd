class_name CounterView
extends Control

signal inspect_requested
var _portrait: TextureRect
var _item_image: TextureButton
var _speech: Label
var _speech_panel: PanelContainer

func _ready() -> void:
	_portrait = TextureRect.new()
	_portrait.name = "CustomerPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	move_child(_portrait, 1)
	_bounds(_portrait, 0.365, 0.13, 0.565, 0.58)
	_item_image = TextureButton.new()
	_item_image.name = "CounterItemImage"
	_item_image.ignore_texture_size = true
	_item_image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_item_image.tooltip_text = "查看货物 · 不耗时"
	_item_image.pressed.connect(inspect_requested.emit)
	_item_image.add_theme_stylebox_override("focus", CounterTheme.box("00000000", "b78345", 0, 0))
	add_child(_item_image)
	_bounds(_item_image, 0.30, 0.72, 0.465, 0.94)
	_speech_panel = PanelContainer.new()
	_speech_panel.name = "CustomerSpeech"
	add_child(_speech_panel)
	_bounds(_speech_panel, 0.275, 0.245, 0.395, 0.54)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	_speech_panel.add_child(margin)
	_speech = Label.new()
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.max_lines_visible = 5
	_speech.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speech.add_theme_font_size_override("font_size", 16)
	margin.add_child(_speech)

func _bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom

func render(model: Dictionary) -> void:
	%CustomerText.text = model.customer
	%ItemText.text = model.item
	%CounterMessage.text = model.queue
	var visual: Dictionary = model.get("visual", {})
	var active := not String(model.active_id).is_empty()
	_portrait.texture = CounterVisualCatalog.portrait(visual.get("portrait_asset", ""))
	_item_image.texture_normal = CounterVisualCatalog.front(visual.get("item_asset", ""), model.appraisal.get("images", []))
	_item_image.disabled = not active
	_item_image.visible = active and _item_image.texture_normal != null
	_speech_panel.visible = active and not visual.is_empty()
	if not visual.is_empty():
		%CustomerText.text = "%s\n%s\n最迟留到 %s" % [visual.customer_name, visual.attitude, visual.deadline]
		_speech.text = visual.introduction
		if not visual.speech.is_empty(): _speech.text = visual.speech.back().answer
		_speech.tooltip_text = _speech.text
		%ItemText.text = "%s\n证据估值 %s\n已见线索 %d 条" % [visual.item_name, visual.estimate, visual.clues.size()]
	$Room.has_customer = active and _portrait.texture == null
	$Room.has_item = active and _item_image.texture_normal == null
	$Room.queue_redraw()


func set_counter_message(message: String) -> void:
	%CounterMessage.text = message

func set_atmosphere(mode: int, preview: bool, intrusion: bool, haunting: bool, dead: bool) -> void:
	$Room.atmosphere = mode
	$Room.smoke_wrong = intrusion or (preview and mode == 1)
	$Room.lamp_wrong = haunting or (preview and mode == 2)
	$Room.lamp_dead = dead
	_portrait.modulate = Color.WHITE if mode == 0 else Color("c0cccb")
	$Room.queue_redraw()
	%AtmosphereLabel.text = ["灯火初上", "夜深了", "禁时 · 鬼市"][mode]
	if preview: %AtmosphereLabel.text = "美术预览 · " + ["正常营业", "深夜异常", "禁时鬼市"][mode]
	%AtmosphereLabel.tooltip_text = "仅切换视觉，不推进时间、不改变规则或存档。" if preview else ""
