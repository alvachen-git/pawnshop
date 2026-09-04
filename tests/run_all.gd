extends SceneTree

var _failures := 0
var _passes := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_json_provider_loads_catalog()
	_test_in_memory_provider_uses_same_catalog_contract()
	_test_missing_field_is_rejected()
	_test_invalid_enum_is_rejected()
	_test_duplicate_id_is_rejected()
	_test_missing_reference_is_rejected()
	_test_main_scene_and_panel_flow()
	M1Tests.new().run(_expect)
	M2Tests.new().run(_expect)
	M3Tests.new().run(_expect)

	if _failures == 0:
		print("M0–M3 TESTS PASSED · %d assertions" % _passes)
		quit(0)
	else:
		push_error("M0–M3 TESTS FAILED · %d failures / %d passes" % [_failures, _passes])
		quit(1)


func _test_json_provider_loads_catalog() -> void:
	var provider := JsonContentProvider.new("res://data/content_manifest.json")
	var result := provider.load_catalog()
	_expect(result.is_success(), "JSON Provider应加载有效目录。")
	if result.is_success():
		_expect(result.catalog.get_count("items") == 2, "目录应包含2件M2物品定义。")
		_expect(result.catalog.get_count("customers") == 2, "目录应包含2个M2顾客模板。")
		_expect(result.catalog.has_definition("items", "item_blue_bowl"), "物品ID应可查询。")


func _test_in_memory_provider_uses_same_catalog_contract() -> void:
	var json_result := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	if not json_result.is_success():
		_expect(false, "JSON目录必须先成功，才能验证内存Provider。")
		return
	var memory_result := InMemoryContentProvider.new(json_result.catalog).load_catalog()
	_expect(memory_result.is_success(), "内存Provider应返回相同ContentCatalog契约。")
	_expect(memory_result.catalog.get_ids("items") == json_result.catalog.get_ids("items"), "两种Provider应暴露相同物品ID。")


func _test_missing_field_is_rejected() -> void:
	var invalid_source := {"schema_version": 1, "records": [{"id": "incomplete"}]}
	var issues := SourceSchemaValidator.new().validate_collection("items", invalid_source, "memory://missing-field")
	_expect(_has_issue(issues, "missing_field"), "Schema应拒绝缺少必填字段的记录。")


func _test_invalid_enum_is_rejected() -> void:
	var source := _valid_item_source()
	source.records[0].type = "mystery_type"
	var issues := SourceSchemaValidator.new().validate_collection("items", source, "memory://invalid-enum")
	_expect(_has_issue(issues, "invalid_enum"), "Schema应拒绝未知物品类型。")


func _test_duplicate_id_is_rejected() -> void:
	var catalog := ContentCatalog.new()
	var dto := ItemDTO.from_source(_valid_item_source().records[0])
	var definition := ItemDefinition.from_dto(dto)
	_expect(catalog.add_definition("items", definition), "首次添加ID应成功。")
	_expect(not catalog.add_definition("items", definition), "重复ID应被目录拒绝。")


func _test_missing_reference_is_rejected() -> void:
	var catalog := ContentCatalog.new()
	var source := _valid_customer_source()
	source.records[0].item_pool = ["item_not_found"]
	var definition := CustomerDefinition.from_dto(CustomerDTO.from_source(source.records[0]))
	catalog.add_definition("customers", definition)
	var issues := DomainValidator.new().validate_catalog(catalog)
	_expect(_has_issue(issues, "missing_reference"), "领域校验应拒绝不存在的物品引用。")


func _test_main_scene_and_panel_flow() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_expect(packed_scene != null, "主场景应能被加载。")
	if packed_scene == null:
		return
	var main := packed_scene.instantiate()
	root.add_child(main)
	var coordinator := main.get_node("CounterScreen/ScreenFlowCoordinator") as ScreenFlowCoordinator
	_expect(coordinator != null, "主场景应包含独立ScreenFlowCoordinator。")
	if coordinator != null:
		_expect(coordinator.get_active_panel_id() == &"day", "柜台启动时应显示营业Panel。")
		var inventory_button := main.get_node("CounterScreen/Margin/RootLayout/Workspace/SideColumn/Navigation/InventoryButton") as Button
		inventory_button.pressed.emit()
		_expect(coordinator.get_active_panel_id() == &"inventory", "库存按钮应能独立切换Panel。")
		var inventory_panel := main.get_node("CounterScreen/Margin/RootLayout/Workspace/SideColumn/PanelStack/InventoryPanel") as InventoryPanel
		var appraisal_panel := main.get_node("CounterScreen/Margin/RootLayout/Workspace/SideColumn/PanelStack/AppraisalPanel") as AppraisalPanel
		_expect(inventory_panel.visible and not appraisal_panel.visible, "Panel切换应只改变表现层显隐。")
	main.queue_free()


func _valid_item_source() -> Dictionary:
	return {
		"schema_version": 1,
		"records": [{
			"id": "item_test",
			"name_key": "item.test.name",
			"type": "normal",
			"category": "test",
			"tags": [],
			"base_value": 10,
			"value_variance": 0.1,
			"liquidity": 0.8,
			"possible_variants": [],
			"appraisal_actions": [],
			"clues": [],
			"valuation_rules": [],
			"sell_channels": [],
			"buyer_tags": [],
			"ghost_rule_id": "",
			"visual_asset_id": "asset.item.test",
		}],
	}


func _valid_customer_source() -> Dictionary:
	return {
		"schema_version": 1,
		"records": [{
			"id": "customer_test",
			"name_key": "customer.test.name",
			"portrait_asset_id": "asset.customer.test",
			"identity_tags": [],
			"wealth_band": "modest",
			"urgency_range": [0.2, 0.4],
			"honesty_profile": "ordinary",
			"patience": 3,
			"max_quote_rounds": 3,
			"alertness": 0.2,
			"transaction_modes": ["sell"],
			"item_pool": ["item_test"],
			"dialogue_profile_id": "",
			"preferred_categories": [],
			"schedule_tags": [],
		}],
	}


func _has_issue(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS · %s" % message)
	else:
		_failures += 1
		push_error("FAIL · %s" % message)
