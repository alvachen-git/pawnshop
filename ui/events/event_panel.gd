class_name EventPanel
extends IntentPanel

var _history: Label
var _pending := ""

func _ready() -> void:
	super._ready()
	_history = Label.new()
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.add_theme_font_size_override("font_size", 14)
	_column.add_child(_history)

func render(model: Dictionary) -> void:
	super.render(model)
	_history.text = model.get("history", "")
	if model.pending_id != _pending:
		_pending = model.pending_id
		var scroll := _column.get_parent() as ScrollContainer
		scroll.set_deferred("scroll_vertical", 0)
