extends SceneTree

func _initialize() -> void:
	var expected := OS.get_environment("PAWNSHOP_TEST_APPDATA").replace("\\", "/").trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	if expected.is_empty() or not actual.to_lower().begins_with(expected.to_lower() + "/"):
		push_error("FAIL: test user directory is not isolated: " + actual)
		quit(1)
		return
	if OS.has_feature("m8a_windows"):
		push_error("FAIL: export feature must not apply to ordinary editor runs")
		quit(1)
		return
	print("M8A ENV PASS: ", actual)
	quit(0)
