extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL · " + message)

func _initialize() -> void:
	var helper := PawnTests.new()
	helper.check = check
	helper.fresh()
	var saver := SaveManager.new("user://tests/pawn_cross_process.json")
	var s := helper.session(null, saver)
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "write":
		check(s.execute("open_shop").ok, "开铺")
		check(helper.command(s, "pawn", "", 27).ok, "回访票放款")
		helper.advance(s, 15)
		check(helper.command(s, "pawn", "", 20).ok, "候赎票放款")
		helper.end_night(s)
		check(s.execute("continue_run").ok, "保存回访前夜")
	elif mode == "settle":
		check(s.load_checkpoint().ok, "跨进程读取回访前夜")
		check(s.execute("open_shop").ok, "原主到店")
		check(s.counter_model().trade.get("pawn_return", false), "柜台显示真实回访")
		check(s.commerce_command("redeem", s.read_state().pawn_tickets[0].ticket_id).ok, "赎回")
		s.execute("close_shop"); s.execute("wait_until_seal")
		check(s.choose_pawn_disposal(s.read_state().pawn_tickets[1].ticket_id, "transfer").ok, "转当草稿")
		check(s.execute("resolve_night").ok, "保存混合结果")
	else:
		check(s.load_checkpoint().ok, "跨进程读取赎回与转当结果")
		var before := s.read_state()
		check(before.cash == 102 and before.pawn_tickets[0].status == "redeemed" and before.pawn_tickets[1].status == "transferred", "现金和权属恢复")
		check(before.pawn_returns.size() == 1 and before.pawn_returns[0].status == "completed", "原主回访记录恢复")
		check(not s.execute("resolve_night").ok and before == s.read_state(), "重启后不能重复收款")
	print("PAWN PROCESS %s: %d failures" % [mode, failures])
	quit(0 if failures == 0 else 1)
