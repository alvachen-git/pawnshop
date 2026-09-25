class_name PearlGuideView
extends CanvasLayer

var session: RunSession
var canvas: Control
var content: Control
var page := 0
var heading: Label
var status: Label
var study: Button

static func open(owner_view: Node, current: RunSession) -> PearlGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("PearlGuide") as PearlGuideView
	if old != null: return old
	var view := PearlGuideView.new(); view.name = "PearlGuide"; view.session = current
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
	page = posmod(page+direction,3); render()

func refresh_status() -> void:
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_jade")
	study.text = "已掌握珠玉知识 · 免费复看" if known else "研习指南 · 1行动点 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_jade")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页不耗时。"+("珠玉知识已掌握。" if known else why if not why.is_empty() else "研习后，可配合灯、放大镜与珠玉托具验珠。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_jade")
	refresh_status()
	if not result.ok: status.text = result.message

func picture(quality: String, angle: int, hole: bool, rect: Rect2) -> void:
	var image := TextureRect.new(); image.texture = PearlArt.cell(quality,angle,hole)
	image.material = PearlArt.material(); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position; image.size = rect.size; content.add_child(image)

func detail(quality: String, rect: Rect2) -> void:
	var image := TextureRect.new(); image.texture = PearlArt.hole_detail(quality)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.position = rect.position; image.size = rect.size
	content.add_child(image)

func pointer(points: Array[Vector2]) -> void:
	var line := Line2D.new(); line.width = 2; line.default_color = Color("713e20"); content.add_child(line)
	for point in points: line.add_point(point)
	var ring := Line2D.new(); ring.width = 2; ring.default_color = line.default_color; content.add_child(ring)
	for step in 33: ring.add_point(points[-1]+Vector2.from_angle(TAU*step/32.0)*9)

func render() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	heading.text = "珍珠鉴定指南 · %d / 3 · " % (page+1)+["转珠看表层","查看孔口","整串比较"][page]
	if page == 0:
		picture("fine",0,false,Rect2(120,190,290,290)); picture("fine",2,false,Rect2(435,190,290,290))
		text(content,"正常参考 · 正面光",Rect2(150,490,275,40),22); text(content,"正常参考 · 转侧面",Rect2(465,490,280,40),22)
		text(content,"① 光泽与表层",Rect2(785,170,340,48),28)
		text(content,"两图均为正常珠参考。转珠、移灯，看光泽沿弧面移动，认清细小纹理。",Rect2(785,235,340,125))
		text(content,"色差、小凹点都可能正常。仅凭光泽难判真假；翻页看孔口的薄层与底色。",Rect2(785,392,340,132))
	elif page == 1:
		text(content,"正常孔口 · 放大",Rect2(140,170,280,40),24); text(content,"涂层异常 · 放大",Rect2(450,170,285,40),24)
		detail("fine",Rect2(140,220,275,275)); detail("imitation",Rect2(450,220,275,275))
		text(content,"孔壁与表层相接",Rect2(140,507,280,40),21)
		text(content,"薄层翘起",Rect2(450,507,135,40),21); text(content,"露出底色",Rect2(600,507,135,40),21)
		pointer([Vector2(262,506),Vector2(262,474),Vector2(218,380)])
		pointer([Vector2(508,505),Vector2(463,478),Vector2(478,260),Vector2(558,266)])
		pointer([Vector2(657,505),Vector2(695,479),Vector2(651,407)])
		text(content,"② 孔口的交界",Rect2(785,170,340,48),28)
		text(content,"找翘起的薄层，再看下方是否露出不同底色。孔口藏在背面时，继续转珠。",Rect2(785,235,340,130))
		text(content,"单个孔口磕伤不能保证是假珠。表面查验也不能确定天然或养殖来源。",Rect2(785,392,340,130))
	else:
		picture("fine",1,false,Rect2(125,190,290,290)); picture("lower",1,false,Rect2(435,190,290,290))
		text(content,"优质真珠 · 细润光泽",Rect2(150,490,295,40),22); text(content,"低档真珠 · 光散纹粗",Rect2(445,490,300,40),22)
		text(content,"③ 相邻与远处都比较",Rect2(775,170,360,48),27)
		text(content,"选两颗并排看，再换一组。低档真珠的光泽与表面可能较粗，须结合孔口判断。",Rect2(775,235,355,130))
		text(content,"正常色差不等于换配。重新穿线也不等于掺假；最后记录的是整串判断。",Rect2(775,392,355,130))
	refresh_status()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled(); queue_free()
