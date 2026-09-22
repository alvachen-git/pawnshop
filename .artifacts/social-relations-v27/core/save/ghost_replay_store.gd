class_name GhostReplayStore
extends SaveManager

# Replay has no filesystem or library side effects, including archive reads.
var origin: Dictionary = {}
var prior_deaths: Array = []
var prior_bankruptcies: Array = []

func read_archive() -> Array:
	return prior_deaths.duplicate(true)

func read_bankruptcy_archive() -> Array:
	return prior_bankruptcies.duplicate(true)

func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
	return true
