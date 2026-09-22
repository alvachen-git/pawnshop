extends "res://tests/shop_growth.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := second_night()
	fixture(s, "preparation")
	s.growth_command("build", "bench"); s.growth_command("build", "display")
	fixture(s, "facilities")
	s = second_night(); act(s, "open_shop"); driver.drain(s); act(s, "close_shop")
	fixture(s, "closed")
	for stage in 3: s.growth_command("explore", str(stage))
	fixture(s, "discovery")
	var seed_value := 0
	while VarietyService.rng(seed_value, "growth/2/chance").randi_range(0, 99) >= 40: seed_value += 1
	s = buyer_session(seed_value); fixture(s, "buyer")
	print("SHOP GROWTH FIXTURES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
