class_name TradeFeedbackView
extends Control

signal finished
signal money_revealed
const DURATION := 0.72
var _paper: PanelContainer
var _subject: Label
var _step: Label
var _money: Label
var _tween: Tween
var _stamp_sound: AudioStreamPlayer
var record: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 19
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(550, 170)
	_paper.add_theme_stylebox_override("panel", CounterTheme.box("e5d5b3", "a38b63", 24, 18))
	center.add_child(_paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_paper.add_child(column)
	for size in [20, 24, 20]:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", Color("302a24"))
		column.add_child(label)
	_subject = column.get_child(0)
	_step = column.get_child(1)
	_money = column.get_child(2)
	_stamp_sound = AudioStreamPlayer.new()
	_stamp_sound.stream = preload("res://assets/opening/stamp.wav")
	_stamp_sound.volume_db = -16
	add_child(_stamp_sound)
	hide()

func present(receipt: Dictionary, customer: String = "") -> void:
	cancel()
	record = receipt.duplicate(true)
	_subject.text = (customer + " · " if not customer.is_empty() else "") + receipt.item
	_step.text = "客人交货" if receipt.kind in ["acquisition", "pawn_loan"] else "核妥当票" if receipt.kind in ["redemption", "extension"] else "交货收款" if receipt.kind == "sale" else receipt.title
	_money.text = ""
	_step.add_theme_color_override("font_color", Color("302a24"))
	show()
	_tween = create_tween()
	_tween.tween_interval(0.24)
	_tween.tween_callback(func() -> void:
		_step.text = {"acquisition": "收讫 · 收入现货", "pawn_loan": "当票已开 · 留铺保管", "redemption": "赎讫 · 原物交还", "extension": "续当留物", "sale": "交货收款"}.get(receipt.kind, receipt.title)
		if receipt.get("due_night", 0) > 0: _step.text += " · 第%d夜到期" % receipt.due_night
		if receipt.kind in ["acquisition", "pawn_loan", "redemption", "extension", "sale"]:
			_step.add_theme_color_override("font_color", Color("923d30"))
			_stamp_sound.play()
	)
	_tween.tween_interval(0.24)
	_tween.tween_callback(func() -> void:
		_money.text = "现银 %d → %d 银元（%+d）" % [receipt.before, receipt.after, receipt.amount] if receipt.kind != "departure" else receipt.note
		money_revealed.emit()
	)
	_tween.tween_interval(0.24)
	_tween.tween_callback(func() -> void: hide(); finished.emit())

func cancel() -> void:
	if _tween != null: _tween.kill()
	if _stamp_sound != null: _stamp_sound.stop()
	hide()

func _input(event: InputEvent) -> void:
	# Eat rapid mouse/key submissions while the paid result is shown.
	if visible and (event is InputEventMouseButton or event is InputEventKey):
		get_viewport().set_input_as_handled()
