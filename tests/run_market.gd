extends SceneTree

var failures := 0
var passes := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL · " + message)
func run() -> void:
	MarketTests.new().run(check)
	print("MARKET TESTS: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
