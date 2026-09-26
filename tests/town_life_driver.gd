extends "res://tests/integrated_test_driver.gd"
func drain(s: RunSession) -> void:
	for guard in 8:
		super.drain(s)
		var dialogue := MedicineStory.dialogue(s._day.state)
		if dialogue.is_empty(): return
		check.call(s.execute("medicine_talk",dialogue.key).ok,"complete medicine conversation before continuing")
