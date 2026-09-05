extends SceneTree

var failures := 0
var files: Array[String] = []

func verify_resource_references(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): verify_resource_references(child)
	elif value is Array:
		for child in value: verify_resource_references(child)
	elif value is String and value.begins_with("res://"):
		check(FileAccess.file_exists(value) or ResourceLoader.exists(value), "JSON resource reference is packed " + value)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func walk(path: String) -> void:
	var directory := DirAccess.open(path)
	check(directory != null, "open packed directory " + path)
	if directory == null: return
	directory.include_hidden = true
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir(): walk(path.path_join(name))
		else: files.append(path.path_join(name))
		name = directory.get_next()
	directory.list_dir_end()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("FAIL: expected PCK, build specification, output report")
		quit(1); return
	var specification: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	check(not FileAccess.file_exists("res://core/bootstrap.gd"), "audit starts outside source project")
	check(ProjectSettings.load_resource_pack(args[0]), "mount final exported PCK")
	walk("res://")
	files.sort()
	var actual_json: Array[String] = []
	for path in files:
		if path.ends_with(".json"): actual_json.append(path)
		check(not path.begins_with("res://tests/") and not path.begins_with("res://tools/") and not path.begins_with("res://docs/") and not path.begins_with("res://design/"), "no development directory: " + path)
		check(not "_review" in path and not "autosave" in path and not path.ends_with(".docx"), "no review/save/document: " + path)
	var expected_json: Array = specification.json_files.duplicate()
	expected_json.sort()
	check(actual_json == expected_json, "exported JSON set exactly matches production manifest closure")
	for path in expected_json:
		check(FileAccess.file_exists(path), "packed JSON exists " + path)
		var bytes := FileAccess.get_file_as_bytes(path)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256); context.update(bytes)
		check(context.finish().hex_encode().to_upper() == specification.json_sha256[path], "packed JSON equals source bytes " + path)
		var parser := JSON.new()
		check(parser.parse(bytes.get_string_from_utf8()) == OK, "packed JSON parses " + path)
		verify_resource_references(parser.data)
	for path in specification.visual_files:
		check(ResourceLoader.load(path) is Texture2D, "dynamic ART02 image loads from PCK " + path)
	var font := ResourceLoader.load("res://assets/fonts/NotoSansSC.ttf") as FontFile
	check(font != null, "bundled font loads from PCK")
	if font != null:
		check(not font.allow_system_fallback, "font does not silently depend on system fallback")
		for character in str(specification.font_characters):
			check(font.has_char(character.unicode_at(0)), "bundled font contains glyph " + character)
	var cache := FileAccess.get_file_as_string("res://.godot/global_script_class_cache.cfg")
	check(not "res://tests/" in cache and not "Tests" in cache, "exported class cache contains no test classes")
	check(ResourceLoader.exists("res://scenes/main.tscn"), "main scene is packed")
	var report := {"passed": failures == 0, "files": files, "json_files": actual_json,
		"dynamic_images_checked": specification.visual_files.size(),
		"font_glyphs_checked": str(specification.font_characters).length(),
		"scope": "PCK resource audit using editor in empty project; not release EXE gameplay acceptance"}
	var output := FileAccess.open(args[2], FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t")); output.close()
	print("M8A PACK AUDIT: %d files, %d failures" % [files.size(), failures])
	quit(0 if failures == 0 else 1)
