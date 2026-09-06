extends "res://tests/ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "m2"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m3_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	await _click("开铺")
	_check(not _session.counter_model().active_id.is_empty(), "开铺出现可交易顾客")
	await _capture("01_customer")
	await _click("对话")
	await _click("问：有没有修补过？ · 5分钟")
	await _capture("02_dialogue")
	await _click("鉴定")
	for label in ["识货：观察器型 · 5分钟", "辨真：放大镜查看底足 · 10分钟", "辨真：侧光检查釉面 · 10分钟"]:
		await _click(label)
	_check(_session.counter_model().appraisal.body.contains("18–25"), "鼠标鉴定揭露真实修补证据")
	await _capture("03_evidence")
	await _click("记录判断：有修补/瑕疵")
	await _click("交易")
	await _click_trade_intent("pressure", "repair")
	_check(_session.counter_model().trade.asking_price == 32, "证据施压降低要价")
	await _capture("04_negotiation")
	var price := _find_spin(_main)
	price.value = 18
	await _click("正式报价并收购")
	_check(_session.read_state().cash == 82 and _session.read_state().inventory_instances.size() == 1, "报价输入后真实扣款并入库")
	await _click("库存")
	await _capture("05_inventory")
	await _click("账本")
	await _capture("06_ledger")
	await _click("交易")
	await _click("拒绝收货 · 5分钟")
	_check(_session.read_state().game_minutes == 45, "排队顾客可接续入场并付出拒绝成本")
	await _click("营业")
	await _click("关门（本夜不可重开）")
	await _click("等到封铺（消耗全部剩余时间）")
	await _click("结算本夜（占位）并自动保存")
	_check(_session.read_state().phase == "day_summary", "交易后仍可日结存档")
	await _capture("07_summary")
	await _click("进入下一夜")
	await _click("开铺")
	await _click("鉴定")
	await _click("记录判断：完好真品")
	await _click("交易")
	price.value = 60
	await _click("正式报价并收购")
	_check(_session.read_state().cash == 22 and _session.read_state().inventory_instances.size() == 2, "第二夜错误判断仍会真实付出高价")
	await _click("营业")
	await _click("读取夜末存档")
	await create_timer(0.3).timeout
	await _click_button(_find_dialog(_main).get_ok_button())
	_check(_session.read_state().cash == 82 and _session.read_state().inventory_instances.size() == 1 and _session.read_state().phase == "pre_open", "UI读档恢复上次库存/现金且丢弃未存夜内交易")
	for night in 2:
		await _click("开铺")
		await _click("等到封铺（消耗全部剩余时间）")
		await _click("结算本夜（占位）并自动保存")
		await _click("进入下一夜" if night == 0 else "结束本轮试玩")
	_check(_session.read_state().phase == "run_ended" and _session.read_state().inventory_instances.size() == 1, "含收购记录的三夜UI循环完成")
	await _capture("08_finished")
	print("M2 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _find_spin(node: Node) -> SpinBox:
	if node is SpinBox: return node
	for child in node.get_children():
		var found := _find_spin(child)
		if found != null: return found
	return null
