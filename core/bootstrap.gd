class_name Bootstrap
extends Node

signal content_ready(catalog: ContentCatalog)
signal content_failed(issues: Array)

@export_file("*.json") var manifest_path := "res://data/content_manifest.json"
@export var save_path := "user://p0/autosave_v12.json"
@export var save_library_path := ""

var catalog: ContentCatalog
var session: RunSession
var preview_stage := ""
var growth_preview := ""
var appraisal_preview := ""
var bargaining_preview := ""
var condition_preview := ""
var preview_version := 23
var unified_preview := ""
const WEALTHY_PREVIEWS := ["wealthy", "wealthy-appraised", "advertisement"]
const UNIFIED_PREVIEWS := {
	"wealthy": "wealthy/ready", "wealthy-appraised": "wealthy/appraised", "advertisement": "wealthy/advertisement-closed",
	"introduction": "unified/introduction", "contract": "unified/contract",
	"upgrade": "unified/upgrade", "fan": "unified/fan-sound",
	"informed": "unified/informed-ready", "ordinary": "unified/ordinary-ready", "urgent": "unified/urgent-ready",
	"no-bench": "unified/no-bench", "intact": "unified/intact", "minor": "unified/minor", "major": "unified/major", "stack": "unified/stack",
	"plaque": "unified-social/plaque", "delivered": "unified-social/delivered",
	"bedtime": "unified-story/bedtime", "call": "unified-story/call", "dream": "unified-story/dream", "reunion": "unified-story/ready",
	"companion": "unified-companion/idle-8"
}


func initialize() -> ContentLoadResult:
	if OS.is_debug_build() and Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--precision-preview=")): save_path = "user://tests/precision-preview/unused.json"
	var provider := JsonContentProvider.new(manifest_path)
	var result := provider.load_catalog()
	if result.is_success():
		catalog = result.catalog
		var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
		if definition == null:
			result.issues.append(ContentIssue.new("error", "missing_run", manifest_path, "default_run_id", "缺少默认运行定义。"))
			content_failed.emit(result.issues)
			return result
		if OrdinarySamplePlan.enabled(definition) or SevenNightPlan.enabled(definition):
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int():
					definition._seed = int(argument.trim_prefix("--seed=")) & 0x7fffffff
					definition._randomize_seed = false
		if not unified_preview.is_empty():
			preview_stage = unified_preview
			preview_version = 31 if unified_preview in WEALTHY_PREVIEWS else 30
		if not preview_stage.is_empty(): save_path = "user://tests/v%d_preview/" % preview_version + preview_stage + ".json"
		var saves := SaveManager.new(save_path)
		if save_path == "user://p0/autosave_v12.json":
			for old_path in ["user://p0/autosave_v11.json", "user://p0/autosave_v10.json", "user://p0/autosave_v9.json"]:
				if FileAccess.file_exists(old_path):
					saves.import_checkpoint_path = old_path
					break
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v11.json":
			for old_path in ["user://p0/autosave_v10.json", "user://p0/autosave_v9.json"]:
				if FileAccess.file_exists(old_path):
					saves.import_checkpoint_path = old_path
					break
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v10.json":
			saves.import_checkpoint_path = "user://p0/autosave_v9.json" if FileAccess.file_exists("user://p0/autosave_v9.json") else "user://p0/autosave_v8.json"
			saves.prior_version_path = "user://p0/autosave_v8.json"
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v9.json":
			saves.import_checkpoint_path = "user://p0/autosave_v8.json"
			saves.prior_version_path = "user://p0/autosave_v8.json"
			saves.legacy_archive_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v8.json":
			saves.prior_version_path = "user://p0/autosave_v7.json"
		if save_path == "user://p0/autosave_v7.json":
			saves.legacy_archive_path = "user://p0/autosave.json"
			saves.prior_version_path = "user://p0/autosave_v6.json"
		saves.library = SaveLibrary.new() if not save_path.begins_with("user://tests/") else null
		if saves.library != null and not save_library_path.is_empty(): saves.library = SaveLibrary.new(save_library_path)
		if SpecialGuests.enabled(definition) and definition.variety.special_guests.version == 2 and saves.library != null:
			saves.library = SaveLibrary.new("user://special_guests_v45/library.json")
		if SpecialGuests.enabled(definition) and definition.variety.special_guests.version == 3 and saves.library != null:
			saves.library = SaveLibrary.new("user://special_guests_v46/library.json")
		if MedicineStory.enabled(definition) and saves.library != null:
			saves.library = SaveLibrary.new("user://medicine_huaian_v47/library.json")
		if FirstDebt.enabled(definition) and not preview_stage.is_empty():
			saves.library = SaveLibrary.new("user://tests/v%d_preview/" % preview_version + preview_stage + "_library.json")
		if TownLife.enabled(definition) and saves.library != null: saves.library = SaveLibrary.new("user://%s/library.json" % definition.id)
		# Seed overrides mutate the runtime definition; keep save validation on the
		# authored catalog in that debugging mode.
		if saves.library != null and not Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--seed=")):
			saves.library.register_catalog(manifest_path, catalog)
		saves.catalog = catalog
		session = RunSession.new(definition, catalog.content_version, saves, catalog)
		if PrecisionPreview.from_arguments(session):
			get_tree().root.title = "鬼市当铺 · 鉴定测试预置 · 进度不保存"
			var overlay := CanvasLayer.new(); overlay.layer = 110; add_child(overlay)
			var label := Label.new(); label.text = "鉴定测试预置 · 本次进度不保存"; label.theme = CounterTheme.build()
			label.add_theme_font_size_override("font_size",16); label.add_theme_color_override("font_color",Color.WHITE)
			label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_outline_size",3)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			overlay.add_child(label); label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); label.offset_left = -220; label.offset_right = 220
		if (not appraisal_preview.is_empty() or not bargaining_preview.is_empty() or not condition_preview.is_empty()) and FanAppraisalService.enabled(definition):
			var directory := "res://.godot/qa/shop-appraisal/" if bargaining_preview.is_empty() else "res://.godot/qa/fan-bargaining/"
			var stage := appraisal_preview if bargaining_preview.is_empty() else bargaining_preview
			if not condition_preview.is_empty():
				directory = "res://.godot/qa/fan-condition/"
				stage = condition_preview
			var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + stage + ".json"))
			var codec := SaveCodec.new()
			var state := codec.decode(payload, definition, catalog.content_version, catalog, true)
			if state == null:
				push_error("识扇试玩资料无效，请重新运行试玩入口：" + codec.error_message)
				session = null
				return result
			state.run_token = Crypto.new().generate_random_bytes(16).hex_encode()
			state.ghost_origin.run_token = state.run_token
			session._day.state = state
		if not growth_preview.is_empty() and ShopGrowthService.enabled(definition):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-growth/" + growth_preview + ".json"))
			var codec := SaveCodec.new()
			var state := codec.decode(data, definition, catalog.content_version, catalog, true)
			if state == null:
				push_error("当铺成长试玩资料无效，请重新运行 tools/play_shop_growth.ps1：" + codec.error_message)
				session = null
				return result
			state.run_token = Crypto.new().generate_random_bytes(16).hex_encode()
			state.ghost_origin.run_token = state.run_token
			state.death_archive.assign(session._day.state.death_archive)
			state.bankruptcy_archive.assign(session._day.state.bankruptcy_archive)
			session._day.state = state
		if not preview_stage.is_empty():
			var fixture_path := "res://.godot/qa/" + String(UNIFIED_PREVIEWS[unified_preview]) + ".json" if not unified_preview.is_empty() else "res://.godot/qa/v%d/" % preview_version + preview_stage + ".json"
			if FirstDebt.enabled(definition): fixture_path = "res://docs/qa/first-debt-v%d/fixtures/" % preview_version + preview_stage + ".json"
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
			var codec := SaveCodec.new()
			var preview := codec.decode(data, definition, catalog.content_version, catalog, true)
			if preview == null:
				push_error("快速试玩资料无效，请重新运行对应版本的试玩入口：" + codec.error_message)
				session = null
				return result
			if FirstDebt.enabled(definition):
				if not saves.library.adopt({"state": preview, "run": definition, "catalog": catalog}, session):
					push_error("快速试玩档案无法载入：" + saves.library.error_message)
					session = null
					return result
			else: session._day.state = preview
		if OrdinarySamplePlan.enabled(definition) or SevenNightPlan.enabled(definition): print("RUN SEED: ", session.read_state().run_seed)
		if SevenNightPlan.enabled(definition) and "--log-plan" in OS.get_cmdline_user_args(): print("SEVEN VISIT PLAN: ", JSON.stringify(session.read_state().seven_plan))
		if FamiliarStories.enabled(definition) and "--log-plan" in OS.get_cmdline_user_args(): print("FAMILIAR STORY PLAN: ", JSON.stringify(session.read_state().familiar_plan))
		content_ready.emit(catalog)
	else:
		content_failed.emit(result.issues)
	return result
