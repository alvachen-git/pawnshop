class_name WatchGuideView
extends CanvasLayer

var session: RunSession
var canvas: Control
var content: Control
var page := 0
var heading: Label
var status: Label
var study: Button
var player: AudioStreamPlayer
var pulse: Label
var elapsed := 0.0
var sample := PackedFloat32Array()
var pulse_enabled: CheckButton
var sample_note: Label
var playback_status: Label
var progress: ProgressBar
var sample_buttons: Array[Button] = []
var active_sample := ""

static func open(owner_view: Node, current: RunSession) -> WatchGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("WatchGuide") as WatchGuideView
	if old != null: return old
	var view := WatchGuideView.new(); view.name = "WatchGuide"; view.session = current
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	layer = 95
	var root_control := Control.new(); add_child(root_control); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("17120eea"); root_control.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.size = Vector2(1280,720); canvas.theme = CounterTheme.build(); root_control.add_child(canvas)
	var paper := Panel.new(); paper.position = Vector2(70,35); paper.size = Vector2(1140,650); paper.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(paper)
	heading = text(canvas,"",Rect2(110,62,900,48),32)
	button(canvas,"收起 · Esc",Rect2(1010,61,155,44),queue_free,"close_guide")
	content = Control.new(); canvas.add_child(content)
	status = text(canvas,"",Rect2(115,562,1040,46),20)
	button(canvas,"上一页",Rect2(115,620,150,44),turn.bind(-1),"previous")
	button(canvas,"下一页",Rect2(280,620,150,44),turn.bind(1),"next")
	study = button(canvas,"",Rect2(640,620,510,44),learn,"study")
	player = AudioStreamPlayer.new(); player.volume_db = -6; add_child(player)
	player.finished.connect(finish_sample)
	session.changed.connect(refresh_status); session.restored.connect(queue_free)
	root_control.resized.connect(func() -> void:
		var scale_factor := minf(root_control.size.x/1280.0,root_control.size.y/720.0)
		canvas.scale = Vector2.ONE*scale_factor; canvas.position = (root_control.size-Vector2(1280,720)*scale_factor)/2)
	root_control.resized.emit(); render()

func text(parent: Node, value: String, rect: Rect2, font := 23) -> Label:
	var label := Label.new(); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value; label.add_theme_font_size_override("font_size",font); label.add_theme_color_override("font_color",Color("382919")); parent.add_child(label)
	label.position = rect.position; label.size = rect.size
	return label

func button(parent: Node, value: String, rect: Rect2, action: Callable, id: String) -> Button:
	var b := Button.new(); b.name = id; b.text = value; b.position = rect.position; b.size = rect.size
	b.add_theme_font_size_override("font_size",22); CounterTheme.style_paper_button(b); b.pressed.connect(action); parent.add_child(b); return b

func turn(direction: int) -> void:
	page = posmod(page+direction,2); render()

func refresh_status() -> void:
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_watch")
	study.text = "已掌握钟表知识 · 可免费复看" if known else "研习指南 · 1行动点 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_watch")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页、试听不耗时。" + ("钟表知识已掌握。" if known else why if not why.is_empty() else "研习后，可配合钟表开验具鉴定。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_watch")
	refresh_status()
	if not result.ok: status.text = result.message

func render() -> void:
	player.stop(); pulse = null; sample_note = null; pulse_enabled = null
	playback_status = null; progress = null; sample_buttons.clear(); active_sample = ""
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	heading.text = "名表鉴定指南 · %d / 2 · " % (page+1)+["听走时","看机芯"][page]
	if page == 0:
		text(content,"上足弦后，滴答应接连不断，间隔均匀。平放听过，再竖起来听；留意空拍、反复停顿，或停下后不再走动。",Rect2(115,135,1030,100))
		for i in 3:
			text(content,["平放、竖放都接连滴答，\n间隔均匀，直到试听结束。","平放连续；竖放会断几拍，\n随后恢复，过一阵又停顿。","上足弦也会半途停下，\n余下时间不再滴答。"][i],Rect2(115+i*345,255,320,90),22)
		for i in 3:
			var b := button(content,["试听正常走时","试听竖放停顿","试听中途停走"][i],Rect2(115+i*345,370,320,55),play_sample.bind(["stable","positional","stopping"][i]),"sample_"+str(i))
			b.toggle_mode = true; sample_buttons.append(b)
		button(content,"停止试听",Rect2(115,444,180,44),stop_sample,"stop_sample")
		pulse_enabled = CheckButton.new(); pulse_enabled.text = "节拍辅助"; pulse_enabled.position = Vector2(330,444); pulse_enabled.size = Vector2(180,44); content.add_child(pulse_enabled)
		pulse = text(content,"",Rect2(530,444,90,45))
		playback_status = text(content,"每段8秒，请听完整段。",Rect2(650,438,495,36),20)
		progress = ProgressBar.new(); progress.position = Vector2(650,480); progress.size = Vector2(495,12); progress.max_value = WatchAppraisal.LENGTH; progress.show_percentage = false; content.add_child(progress)
		sample_note = text(content,"开头相同，留意后半段。声音连续不能证明名表身份；实物停顿的位置也可能不同。",Rect2(115,511,1020,46),20)
	elif page == 1:
		var patterns := WatchMovementPatterns.enabled(session.definition)
		text(content,"原配机芯参考 · 开盖后，用放大镜对照这两处。",Rect2(115,130,1030,48))
		var item := ItemInstance.new(); item.selected_variant_id = "sound"
		var detail := AtlasTexture.new(); detail.atlas = WatchArt.movement(item); detail.region = Rect2(155,105,285,285)
		var art := TextureRect.new(); art.name = "genuine_reference"; art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.texture = detail; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.position = Vector2(145,185); art.size = Vector2(360,360); content.add_child(art)
		for j in 2:
			var normalized: Vector2 = [Vector2(.49,.32),Vector2(.645,.44)][j] if patterns else WatchAppraisal.spot(item,j)
			var point := art.position+(normalized*512-Vector2(155,105))/285*360
			var ring := Line2D.new(); ring.width = 2; ring.default_color = Color("f5deb0"); content.add_child(ring)
			for step in 49: ring.add_point(point+Vector2.from_angle(TAU*step/48.0)*31)
			var marker := text(content,"①" if j == 0 else "②",Rect2(point+Vector2(-15,-66),Vector2(40,40)),30)
			marker.add_theme_color_override("font_color",Color.WHITE); marker.add_theme_color_override("font_shadow_color",Color.BLACK); marker.add_theme_constant_override("shadow_offset_x",2); marker.add_theme_constant_override("shadow_offset_y",2)
		text(content,"① 夹板与轮系",Rect2(565,210,565,45),28)
		text(content,"核对弧形夹板的轮廓，再比较大小齿轮的直径比例与周围间隙。刻字相同，也要看结构。" if patterns else "记住弧形夹板的外沿、转折，以及齿轮的相对位置。拿到实物时，逐处对照，别只认刻字。",Rect2(565,265,565,85),23)
		text(content,"② 刻字与固定处" if patterns else "② 机芯座与固定处",Rect2(565,367,565,45),28)
		text(content,"刻字：PATEK PHILIPPE / GENEVE。\n逐字核对，再看座圈是否贴合、螺钉旁有无转接件。" if patterns else "看机芯外缘是否贴合座圈，固定螺钉的位置是否相应，再留意有无额外的垫圈或转接件。",Rect2(565,422,565,100),23)
	refresh_status()

func play_sample(operation: String) -> void:
	sample = WatchEconomy.sample_ticks(operation,"vertical",0.4); elapsed = 0
	active_sample = {"stable":"正常走时","positional":"竖放停顿","stopping":"中途停走"}[operation]
	for i in sample_buttons.size(): sample_buttons[i].set_pressed_no_signal(operation == ["stable","positional","stopping"][i])
	progress.value = 0
	player.stream = WatchSound.stream(sample); player.play()
	playback_status.text = "%s · 0.0 / 8秒" % active_sample

func stop_sample() -> void:
	player.stop()
	for b in sample_buttons: b.set_pressed_no_signal(false)
	if playback_status != null: playback_status.text = "已停止 · 可重新试听完整8秒。"
	if pulse != null: pulse.text = ""

func finish_sample() -> void:
	if progress == null: return
	progress.value = WatchAppraisal.LENGTH
	playback_status.text = active_sample+" · 已听完8秒"
	for b in sample_buttons: b.set_pressed_no_signal(false)

func _process(_delta: float) -> void:
	if pulse == null: return
	if not player.playing: pulse.text = ""; return
	elapsed = clampf(player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency(),0,WatchAppraisal.LENGTH); pulse.text = ""
	progress.value = elapsed
	playback_status.text = "%s · %.1f / 8秒" % [active_sample,elapsed]
	if pulse_enabled.button_pressed:
		for t in sample:
			if elapsed >= t and elapsed-t < .11: pulse.text = "嗒"; break

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled(); queue_free()
