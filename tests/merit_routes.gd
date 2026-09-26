extends "res://tests/recovery_routes.gd"

func test_manifest() -> String:
	return "res://data/first_debt_merit_manifest.json"

func verify(s: RunSession, label: String) -> void:
	check(s._day.state.hidden_merit == (10 if FirstDebt.settled(s._day.state) else 0), "merit tracks settlement only " + label)
	super.verify(s, label)

func fd(s: RunSession, id: String, option: String) -> void:
	super.fd(s,id,option)
	if id == "fd_settle" and option in ["return","pay"]:
		var before := s._day.state.hidden_merit
		var count := HiddenMerit.gameplay_event_count(s._day.state)
		check(s.event_command(HiddenMerit.ECHO,"seen").ok,"acknowledge before continuing business")
		check(s._day.state.hidden_merit == before and HiddenMerit.gameplay_event_count(s._day.state) == count,"ack never changes gameplay event count")
