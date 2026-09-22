extends SceneTree

func _initialize() -> void:
	var translation := Translation.new()
	translation.locale = "zh_CN"
	var messages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/opening/text_zh_CN.json"))
	for key in messages: translation.add_message(key, messages[key])
	var result := ResourceSaver.save(translation, "res://data/opening/zh_CN.translation")
	print("OPENING TRANSLATION: ", result)
	quit(0 if result == OK else 1)
