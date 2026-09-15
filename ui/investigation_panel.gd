class_name InvestigationPanel
extends IntentPanel

var session: RunSession

func _ready() -> void:
	super._ready()
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_constant_override("line_spacing", 7)

func bind(value: RunSession) -> void:
	session = value
	intent.connect(func(command: String, _id: String, detail: String, _amount: int) -> void: session.investigation_command(command, detail))
	session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var model := InvestigationService.model(session._day, session._counter.catalog)
	# The letter stays sealed until the explicit reading action.
	if session.message.begins_with("你付了") or session.message.begins_with("口信已托出"): model.body = session.message + "\n\n" + model.body
	render(model)
	for button in _buttons.get_children():
		button.custom_minimum_size.y = 54
		CounterTheme.style_paper_button(button)
