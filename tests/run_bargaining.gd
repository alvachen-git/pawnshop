extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	BargainingTests.new().run(check)
	print("BARGAINING TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
