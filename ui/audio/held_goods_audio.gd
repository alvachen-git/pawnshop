class_name HeldGoodsAudio
extends Node

const CLIPS := [preload("res://assets/special_guests/audio/drips.wav"), preload("res://assets/special_guests/audio/wood.wav"), preload("res://assets/special_guests/audio/rustle.wav")]
var room: PrivateRoomView
var player: AudioStreamPlayer
var caption: Label
var random := RandomNumberGenerator.new()
var remaining := 0.0
var last_clip := -1
var armed := false
var context := ""
var noted_context := ""
var play_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.randomize()
	player = AudioStreamPlayer.new()
	player.name = "HeldGoodsSound"
	player.volume_db = -20
	add_child(player)
	caption = Label.new()
	caption.name = "HeldGoodsCaption"
	caption.z_index = 100
	caption.text = "楼下轻轻响了一声。你屏住呼吸，那声音又停了。"
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("d8c5a3"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(caption)
	caption.hide()

func _process(delta: float) -> void:
	var model: Dictionary = room._model
	var wet: Dictionary = model.get("wet_audio", {})
	var key := str(wet.get("token", "")) + "/" + str(model.get("night", 0))
	var allowed: bool = room.is_visible_in_tree() and model.get("phase") == "private_room" and not model.get("pending", true) and not wet.get("held", []).is_empty() and not get_tree().paused
	if allowed: allowed = not blocked(get_tree().current_scene)
	if key != context:
		context = key
		reset()
	if not allowed:
		reset()
		return
	if not armed:
		armed = true
		remaining = random.randf_range(1.0, 2.0)
	remaining -= delta
	if caption.visible and not player.playing: caption.hide()
	if remaining > 0 or player.playing: return
	var choices := [0, 1, 2]
	choices.erase(last_clip)
	last_clip = choices[random.randi_range(0, choices.size() - 1)]
	player.stream = CLIPS[last_clip]
	player.play()
	play_count += 1
	remaining = random.randf_range(4.0, 8.0)
	if noted_context != str(wet.get("token", "")):
		noted_context = str(wet.get("token", ""))
		caption.position = Vector2(32, room.size.y - 70)
		caption.show()

func reset() -> void:
	armed = false
	remaining = 0
	if player != null: player.stop()
	if caption != null: caption.hide()

func blocked(node: Node) -> bool:
	if node == null: return false
	if node is Window and node != get_tree().root and node.visible: return true
	if node is CanvasItem and not node.is_visible_in_tree(): return false
	if node is SessionMenuView or node is MirrorDreamView or node is MirrorReunionView or node is FirstDebtConversation: return true
	if node == room._observation or node == room._keepsakes: return true
	for child in node.get_children():
		if blocked(child): return true
	return false
