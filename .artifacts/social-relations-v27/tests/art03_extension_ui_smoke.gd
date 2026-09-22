extends "res://tests/m3_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "art03_extension"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/art03_extension_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	_check(_session != null, "续当验收夹具载入")
	if _session == null: quit(1); return
	await _click("开铺")
	await _click("交易")
	_find_trade(_main)._pawn_price.value = 27
	await _click("正式报价并活当")
	await _click("库存")
	await _click("查看货物 · 青花小碗")
	await _click("查看当票")
	var ledger := _main.find_child("LedgerPanel", true, false) as LedgerPanel
	_check(ledger._pages[2].is_visible_in_tree(), "库存入口直接打开当票页")
	await _finish_night()
	await _click("进入下一夜")
	await _click("开铺")
	await _click("账本")
	await _capture("01_before_extension")
	await _click("到柜台接待原当户")
	await _click("验票收息，续当留物")
	_check(_session.read_state().cash == 76, "续当实际收入3银元")
	var ticket: Dictionary = _session.counter_model().ledger.visual.tickets[0]
	_check(ticket.due == 3 and ticket.principal == 27 and ticket.redemption == 33, "续当只延长到期夜次，不改本金和约定赎金")
	await _capture("02_extended_ticket")
	await _click("流水")
	_check(_session.counter_model().ledger.visual.entries.back().amount == 3, "续当费写入真实流水")
	await _capture("03_extension_receipt")
	await _finish_night()
	await _click("进入下一夜")
	await _click("开铺")
	await _click("账本")
	await _click("当票")
	await _click("到柜台接待原当户")
	await _click("验票收赎，交还原物")
	_check(_session.read_state().cash == 109 and _session.read_state().pawn_tickets[0].status == "redeemed", "续当后的当票可以到期赎回")
	await _capture("04_redeemed")
	print("ART03 EXTENSION UI: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
