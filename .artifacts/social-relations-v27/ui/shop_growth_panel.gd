class_name ShopGrowthPanel
extends IntentPanel

var session: RunSession
var section := 0
var tabs: HBoxContainer
var diagram: HBoxContainer

func _ready() -> void:
	super._ready()
	_body.add_theme_font_size_override("font_size", 17)
	tabs = HBoxContainer.new()
	_column.add_child(tabs)
	_column.move_child(tabs, 0)
	for title in ["基础整修", "陈列位", "沿柜查铺"]:
		var button := Button.new()
		button.text = title
		button.name = "GrowthTab%d" % tabs.get_child_count()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.pressed.connect(select.bind(tabs.get_child_count()))
		tabs.add_child(button)
	var scroll := _column.get_parent() as ScrollContainer
	var margin := scroll.get_parent()
	margin.remove_child(scroll)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	tabs.reparent(layout)
	layout.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram = HBoxContainer.new()
	_column.add_child(diagram)
	_column.move_child(diagram, 0)
	visibility_changed.connect(refresh)

func bind(value: RunSession) -> void:
	session = value
	intent.connect(func(command: String, _id: String, detail: String, _amount: int) -> void:
		session.growth_command(command, detail)
		(_column.get_parent() as ScrollContainer).set_deferred("scroll_vertical", 0)
	)
	session.changed.connect(refresh)
	refresh()

func select(index: int) -> void:
	section = index
	refresh()
	(_column.get_parent() as ScrollContainer).scroll_vertical = 0

func refresh() -> void:
	if session == null or not is_visible_in_tree(): return
	render(ShopGrowthReadModels.page(session._day, section))
	AccountPaper.clear(diagram)
	if not session._day.state.shop_growth_enabled: return
	var growth := session._day.state.shop_growth
	var labels: Array = []
	if section == 0: labels = ["工具架\n放大镜 · 灯 · 磁铁\n" + ("台面已整平" if growth.bench else "待整修"), "陈列柜\n一个陈列位\n" + ("柜门已修好" if growth.display else "待整修")]
	elif section == 1: labels = ["陈列位 ①\n" + ("尚未整修" if not growth.display else "空位" if growth.display_id.is_empty() else "货已摆好")]
	else: labels = ["一 · 二 · … · 十六\n沿墙的旧柜", "夹板后的柜格\n已留观察记录" if growth.exploration.size() == 3 else "旧账与柜号\n已核查 %d / 3 步" % growth.exploration.size()]
	for text in labels:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
		diagram.add_child(box)
		var label := AccountPaper.label(box, text, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if section == 1 and not growth.display_id.is_empty():
		var item := InventoryManager.new().find(session._day.state, growth.display_id)
		if item != null:
			var definition := session._counter.catalog.get_definition("items", item.definition_id) as ItemDefinition
			var picture := TextureRect.new()
			picture.texture = CounterVisualCatalog.front(definition.visual_asset_id)
			picture.custom_minimum_size = Vector2(90, 72)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			diagram.add_child(picture)
	for button in _buttons.get_children():
		button.custom_minimum_size.y = 48
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		CounterTheme.style_paper_button(button)
