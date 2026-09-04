class_name RiskPanel
extends EventPanel

func reset_reading_position() -> void:
	var scroll := _column.get_parent() as ScrollContainer
	scroll.set_deferred("scroll_vertical", 0)
