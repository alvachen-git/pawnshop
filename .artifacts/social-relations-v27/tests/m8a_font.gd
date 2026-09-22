extends SceneTree

func _initialize() -> void:
	var font := preload("res://assets/fonts/NotoSansSC.ttf")
	var themed := CounterTheme.build().default_font
	var ok := not font.allow_system_fallback and themed is FontVariation
	for rid in themed.get_rids():
		var coordinates := TextServerManager.get_primary_interface().font_get_variation_coordinates(rid)
		ok = ok and coordinates.get(0x77676874, 0.0) == 400.0
	for character in "鬼市当铺确认取消银元库存典当账本绝当录破铺录，。；：“”《》·–0123456789":
		ok = ok and font.has_char(character.unicode_at(0))
	if not ok:
		push_error("FAIL: bundled glyphs, disabled fallback, or applied weight axis")
		quit(1); return
	print("M8A FONT TESTS PASSED: bundled glyphs; no system fallback; applied weight=400")
	quit(0)
