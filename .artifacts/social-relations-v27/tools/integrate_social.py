from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
def edit(name, old, new, count=1):
    p=ROOT/name
    t=p.read_text(encoding='utf-8-sig')
    if old not in t: raise RuntimeError(f'Missing anchor {name}: {old[:100]}')
    p.write_text(t.replace(old,new,count),encoding='utf-8')
def write_json(name, value):
    p=ROOT/name;p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

manifest=json.loads((ROOT/'data/shop_growth_manifest.json').read_text(encoding='utf-8-sig'))
manifest['content_version']=26;manifest['default_run_id']='social_relations_ten'
manifest['sources'][0]['path']='res://data/social_relations/run.json'
write_json('data/social_relations_manifest.json',manifest)
run=json.loads((ROOT/'data/shop_growth/run.json').read_text(encoding='utf-8-sig'))
run['records'][0]['id']='social_relations_ten'
write_json('data/social_relations/run.json',run)
edit('core/shop/shop_growth_service.gd','return String(run.id) == RUN','return String(run.id) == RUN or SocialRules.enabled(run)')
edit('core/shop/shop_growth_service.gd','if not state.shop_growth_enabled or not opportunity(state).is_empty(): return','if not state.shop_growth_enabled or SocialRules.closed(state) or not opportunity(state).is_empty(): return')
edit('core/state/run_state.gd','var shop_growth_enabled := false','var social_enabled := false\nvar social: Dictionary = {}\nvar shop_growth_enabled := false')
edit('core/state/run_state.gd','state.shop_growth_enabled = ShopGrowthService.enabled(definition)','state.social_enabled = SocialRules.enabled(definition)\n\tif state.social_enabled: state.social = SocialRules.initial()\n\tstate.shop_growth_enabled = ShopGrowthService.enabled(definition)')
edit('core/state/run_state.gd','if shop_growth_enabled: data["shop_growth"] = shop_growth.duplicate(true)','if social_enabled: data["social"] = social.duplicate(true)\n\tif shop_growth_enabled: data["shop_growth"] = shop_growth.duplicate(true)')
edit('core/trade/trade_session.gd','var belittle_used := false','var social_flaw_discount := 0\nvar social_offer_mode := ""\nvar social_last_was_quote := false\nvar belittle_used := false')
edit('core/trade/trade_controller.gd','trade.reserve_price = maxi(1, trade.reserve_price - clue.leverage)','trade.social_flaw_discount += clue.leverage\n\ttrade.reserve_price = maxi(1, trade.reserve_price - clue.leverage)')
edit('core/trade/counter_service.gd','var scenario := TradeScenarioService.for_visit(day.definition, visit)\n\tvar cost := 0','var scenario := TradeScenarioService.for_visit(day.definition, visit)\n\tvisit.trade.social_last_was_quote = false\n\tvar cost := 0')
edit('core/trade/counter_service.gd','if trades.quote(visit.trade, customer, amount, threshold):','visit.trade.social_offer_mode = command\n\t\t\tvisit.trade.social_last_was_quote = true\n\t\t\tif trades.quote(visit.trade, customer, amount, threshold):')
edit('core/day/preparation_service.gd','return ShopGrowthService.preparation_count(state) +','return SocialRules.preparation_count(state) + ShopGrowthService.preparation_count(state) +')
edit('core/customer/customer_manager.gd','InvestigationService.prepare(state, run)\n\t\treturn','InvestigationService.prepare(state, run)\n\t\tMilitaryService.dawn(state, run)\n\t\tif SocialRules.closed(state):\n\t\t\tfor visit in state.visits: visit.status = "suspended"\n\t\treturn')
edit('core/customer/customer_manager.gd','InvestigationService.departed(state, visit, outcome)','ReputationService.finish(state, visit, outcome)\n\tMilitaryService.departed(state, visit, outcome)\n\tInvestigationService.departed(state, visit, outcome)')
# Overlay before player-directed preparation so chosen appointments cannot be removed.
edit('core/day/opening_preparation.gd','rows = NightMarketPlan.overlay(rows, run, catalog, state.run_seed)','rows = NightMarketPlan.overlay(rows, run, catalog, state.run_seed)\n\trows = ReputationService.overlay(state, run, catalog, rows)')
edit('core/save/investigation_save_codec.gd','var version := ShopGrowthService.VERSION if ShopGrowthService.enabled(run) else 23','var version := SocialRules.VERSION if SocialRules.enabled(run) else ShopGrowthService.VERSION if ShopGrowthService.enabled(run) else 23')
edit('core/save/investigation_save_codec.gd','if ShopGrowthService.enabled(run): commands["growth_command"] = [2, 2]','if ShopGrowthService.enabled(run): commands["growth_command"] = [2, 2]\n\tif SocialRules.enabled(run): commands["social_command"] = [2, 2]')
edit('core/save/investigation_save_codec.gd','if row.method == "growth_command" and not result.ok: return null','if row.method in ["growth_command", "social_command"] and not result.ok: return null')
edit('core/save/save_library.gd','const MANIFESTS := [','const MANIFESTS := ["res://data/social_relations_manifest.json", ')
edit('core/save/save_library.gd','const LEGACY := {','const LEGACY := {"social_relations_ten": "user://social_relations_ten/autosave_v26.json", ')
edit('core/save/save_library.gd','const NAMES := {','const NAMES := {"social_relations_ten": "鬼市当铺 · 街坊与军方", ')
edit('core/day/run_session.gd','func can_execute(command: String) -> bool:\n','func can_execute(command: String) -> bool:\n\tif command == "open_shop" and SocialRules.blocked(_day.state): return false\n')
edit('core/day/run_session.gd','NightMarketRisk.settle(_day.state)\n\t\tFeeService.settle','MilitaryService.settle(_day.state)\n\t\tNightMarketRisk.settle(_day.state)\n\t\tFeeService.settle')
edit('core/day/run_session.gd','if result.ok and command == "open_shop": ShopGrowthService.lock_night(_day.state)','if result.ok and command == "open_shop":\n\t\tMilitaryService.spawn_supply(_day.state)\n\t\tShopGrowthService.lock_night(_day.state)')
edit('core/day/run_session.gd','if not replaying and not result.ok:\n','if _day.state.social_enabled and previous != null and previous.social != _day.state.social: _pending_checkpoint = true\n\tif not replaying and not result.ok:\n')
p=ROOT/'core/day/run_session.gd'
p.write_text(p.read_text(encoding='utf-8')+'''\nfunc social_command(command: String, detail := "") -> ActionResult:
\treturn _journal_call("social_command", [command, detail])

func _impl_social_command(command: String, detail := "") -> ActionResult:
\tvar result := MilitaryService.perform(_day, command, detail)
\tif result.ok:
\t\tShopGrowthService.sync(_day.state)
\t\tMarketService.sync(_day.state, definition)
\t\t_persist()
\tmessage = result.message
\treturn result
''',encoding='utf-8')
edit('core/inventory/commerce_service.gd','func trip_reason(day: DayController, buyer: BuyerDefinition) -> String:\n','func trip_reason(day: DayController, buyer: BuyerDefinition) -> String:\n\tif SocialRules.closed(day.state): return "今夜停业，不办新交货；已有约定顺延一夜。"\n')
edit('core/inventory/commerce_service.gd','func sale_reason(day: DayController, item: ItemInstance, buyer: BuyerDefinition) -> String:\n','func sale_reason(day: DayController, item: ItemInstance, buyer: BuyerDefinition) -> String:\n\tif SocialRules.closed(day.state): return "今夜停业，不办新交货。"\n')
edit('core/inventory/commerce_service.gd','day.state.current_night_index < buyer.night_min or day.state.current_night_index > buyer.night_max','MilitaryService.buyer_night(day.state, buyer.id) < buyer.night_min or MilitaryService.buyer_night(day.state, buyer.id) > buyer.night_max',count=10)
edit('core/economy/financial_summary.gd','if state.shop_growth_enabled: result.facility_investment = 0','if state.social_enabled: result.military_expense = 0\n\tif state.shop_growth_enabled: result.facility_investment = 0')
edit('core/economy/financial_summary.gd','"facility_investment": result.facility_investment -= entry.amount','"military_expense": result.military_expense -= entry.amount\n\t\t\t"facility_investment": result.facility_investment -= entry.amount')
edit('core/economy/financial_summary.gd','result.operating_profit = result.realized_profit -','result.operating_profit = result.realized_profit - int(result.get("military_expense", 0)) -')
edit('core/trade/counter_visual_read_models.gd','"asking": visit.trade.asking_price,','"social_feedback": day.state.social_enabled, "asking": visit.trade.asking_price,')
edit('ui/trade/customer_reply_model.gd','var line := String(LINES.get(style, ""))','\tif visual.get("social_feedback", false) and -int(receipt.amount) >= asking: style = "satisfied"\n\tvar line := String(LINES.get(style, ""))')
edit('ui/menu/session_menu_view.gd','var _growth_button: Button','var _social_button: Button\nvar _growth_button: Button')
edit('ui/menu/session_menu_view.gd','func _ready() -> void:\n','func _ready() -> void:\n\t_social_button = Button.new()\n\t_social_button.text = "军方往来"\n\t_social_button.name = "SocialMenuButton"\n\t%RiskButton.get_parent().add_child(_social_button)\n\t_social_button.pressed.connect(_route.bind(&"social"))\n')
edit('ui/menu/session_menu_view.gd','func render(model: Dictionary) -> void:\n','func render(model: Dictionary) -> void:\n\t_social_button.visible = model.get("social", false) and not model.get("in_room", false)\n')
edit('ui/day/day_flow_presenter.gd','_session_menu.render({','_session_menu.render({"social": SocialRules.enabled(definition), ')
edit('ui/day/day_flow_presenter.gd','if state.phase == "open": description = "营业中"','if state.phase == "open": description = "停业守铺 · 只办旧票" if SocialRules.closed(_session._day.state) else "营业中"\n\tif SocialRules.enabled(definition):\n\t\tdescription += SocialReadModels.notice(_session._day.state)\n\t\tcommands.append({"id": "read_social", "label": "查看军方往来", "enabled": true})')
edit('ui/day/day_flow_presenter.gd','var routes := {','var routes := {"read_social": &"social", ')
edit('ui/counter/counter_screen.gd','const PANEL_TITLES := {','const PANEL_TITLES := {"social": "军方往来", ')
edit('ui/counter/counter_screen.gd','_session = session\n\tvar growth_panel','_session = session\n\tvar social_panel := SocialPanel.new()\n\tsocial_panel.panel_id = &"social"\n\tsocial_panel.name = "SocialPanel"\n\t%DayFlowPanel.get_parent().add_child(social_panel)\n\tsocial_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tsocial_panel.hide()\n\t_flow.register_panel(social_panel)\n\tsocial_panel.bind(session)\n\tvar growth_panel')
edit('scenes/start.tscn','res://data/shop_growth_manifest.json','res://data/social_relations_manifest.json')
edit('scenes/start.tscn','user://shop_growth_ten/autosave_v25.json','user://social_relations_ten/autosave_v26.json')
edit('project.godot','config/version="V25-ShopGrowth.2-Facilities"','config/version="V26-SocialRelations.1"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="GhostMarketPawnshop-SocialRelations"')
print('Social integration applied in isolated copy.')
