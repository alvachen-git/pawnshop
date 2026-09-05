extends SceneTree

var passes := 0
var failures := 0

func _initialize() -> void:
	RoomTests.new().run(check)
	print("ROOM TESTS: %d assertions, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("FAIL: " + message)
