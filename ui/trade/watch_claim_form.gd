class_name WatchClaimForm
extends VBoxContainer

signal submitted(detail: String)
var checks := {}
var selections := {}
var submit_button: Button

func build(model: Dictionary) -> void:
	name = "WatchClaimForm"
	add_theme_constant_override("separation",8)
	var hint := Label.new(); hint.text = "勾选这次要谈的说法，可改口；不会改动自己的手记。每类只谈一次。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size",16); add_child(hint)
	for row: Dictionary in model.rows:
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation",10); add_child(line)
		var check := CheckBox.new(); check.name = "claim_"+row.id; check.text = row.label; check.custom_minimum_size = Vector2(100,44); line.add_child(check)
		var choice := OptionButton.new(); choice.name = "say_"+row.id; choice.custom_minimum_size.y = 44; choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(choice)
		choice.add_item("暂不表态"); choice.set_item_metadata(0,"")
		for value in row.options:
			choice.add_item(row.options[value]); choice.set_item_metadata(choice.item_count-1,value)
			if value == (row.previous if row.used else row.default): choice.select(choice.item_count-1)
		check.disabled = not row.reason.is_empty(); choice.disabled = check.disabled
		check.button_pressed = not check.disabled and choice.selected > 0
		checks[row.id] = check; selections[row.id] = choice
		check.toggled.connect(func(_value: bool) -> void: update_submit())
		choice.item_selected.connect(func(_index: int) -> void: check.button_pressed = choice.selected > 0; update_submit())
		if not row.reason.is_empty():
			var note := Label.new(); note.text = row.label+" · "+("已谈过" if row.used else row.reason); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.add_theme_font_size_override("font_size",14); add_child(note)
	submit_button = Button.new(); submit_button.name = "SubmitWatchClaims"; submit_button.text = "提出这番说法 · 5分钟 / 1轮"; submit_button.custom_minimum_size.y = 48
	submit_button.pressed.connect(func() -> void: submitted.emit(JSON.stringify(payload())))
	add_child(submit_button); update_submit()

func payload() -> Dictionary:
	var result := {}
	for part in checks:
		var check: CheckBox = checks[part]; var choice: OptionButton = selections[part]
		if not check.disabled and check.button_pressed and choice.selected > 0: result[part] = choice.get_item_metadata(choice.selected)
	return result

func update_submit() -> void:
	if submit_button != null: submit_button.disabled = payload().is_empty()
