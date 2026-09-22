"""One-time integration against the hash-recorded v23 snapshot."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def patch(name, old, new, count=-1):
    p=root/name; s=p.read_text(encoding='utf-8'); assert old in s,(name,old[:100]); p.write_text(s.replace(old,new,count),encoding='utf-8')
def append(name,s):
    p=root/name;p.write_text(p.read_text(encoding='utf-8')+s,encoding='utf-8')
def write_json(name,data):
    p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
m=json.loads((root/'data/mirror_investigation_manifest.json').read_text(encoding='utf-8'))
m['content_version']=25;m['default_run_id']='shop_growth_ten';m['sources'][0]['path']='res://data/shop_growth/run.json'
write_json('data/shop_growth_manifest.json',m)
r=json.loads((root/'data/mirror_investigation/run.json').read_text(encoding='utf-8'));r['records'][0]['id']='shop_growth_ten'
write_json('data/shop_growth/run.json',r)
patch('scenes/start.tscn','mirror_investigation_manifest.json','shop_growth_manifest.json')
patch('scenes/start.tscn','mirror_investigation_ten/autosave_v23.json','shop_growth_ten/autosave_v25.json')
patch('core/state/run_state.gd','var investigation_enabled := false','var shop_growth_enabled := false\nvar shop_growth: Dictionary = {}\nvar investigation_enabled := false')
patch('core/state/run_state.gd','state.run_definition_id = definition.id','state.run_definition_id = definition.id\n\tstate.shop_growth_enabled = ShopGrowthService.enabled(definition)\n\tif state.shop_growth_enabled: state.shop_growth = ShopGrowthService.initial()')
patch('core/state/run_state.gd','if investigation_enabled: data["investigation"]','if shop_growth_enabled: data["shop_growth"] = shop_growth.duplicate(true)\n\tif investigation_enabled: data["investigation"]')
patch('core/shop/shop_growth_service.gd','action.tool in','action.required_tool in')
patch('core/day/preparation_service.gd','return state.preparation_history.filter','return ShopGrowthService.preparation_count(state) + state.preparation_history.filter',1)
patch('core/trade/counter_service.gd','cost = item.find_action(detail).minutes','cost = ShopGrowthService.appraisal_minutes(day.state, item, detail)')
patch('core/trade/counter_read_models.gd','[action.label, action.minutes]','[action.label, ShopGrowthService.appraisal_minutes(state, item, action.id)]')
patch('core/trade/counter_service.gd','if visit.purpose == "husband_meeting":','if visit.purpose == "display_buyer": return ShopGrowthService.trade_reason(day, command, visit_id, detail, amount)\n\tif visit.purpose == "husband_meeting":',1)
patch('core/trade/counter_read_models.gd','if visit.purpose == "husband_meeting":','if visit.purpose == "display_buyer": return ShopGrowthReadModels.buyer(model, day, visit, message)\n\tif visit.purpose == "husband_meeting":',1)
patch('core/customer/customer_manager.gd','if state.phase == &"pre_open": return','if state.phase == &"pre_open": return\n\tShopGrowthService.sync(state)',1)
patch('core/customer/customer_manager.gd','GhostGuests.arrive(state, visit)','GhostGuests.arrive(state, visit)\n\t\t\t\tShopGrowthService.activate(state, visit)')
patch('core/customer/customer_manager.gd','InvestigationService.departed(state, visit, outcome)','InvestigationService.departed(state, visit, outcome)\n\tShopGrowthService.departed(state, visit, outcome)')
patch('core/day/run_session.gd','if result.ok and prior_visitor != null','if result.ok and command == "open_shop" and _day.state.shop_growth_enabled: _persist()\n\tif result.ok and prior_visitor != null',1)
patch('core/day/run_session.gd','if result.ok and _counter != null:\n','if result.ok and command == "open_shop": ShopGrowthService.lock_night(_day.state)\n\tif result.ok and _counter != null:\n',1)
patch('core/day/run_session.gd','if command == "soul_inspect": return inspect_customer(visit_id)','if command == "soul_inspect": return inspect_customer(visit_id)\n\tvar growth_visit := _counter.customers.active(_day.state)\n\tif growth_visit != null and growth_visit.purpose == "display_buyer":\n\t\tvar ledger_start := _day.state.ledger_entries.size()\n\t\tvar result := ShopGrowthService.trade(_day, command, visit_id, detail, amount)\n\t\tif result.ok:\n\t\t\tif _risk != null: _risk.capture_close(_day.state)\n\t\t\t_events.poll(_day.state, definition)\n\t\t\tMarketService.sync(_day.state, definition)\n\t\t\t_persist()\n\t\t\t_emit_receipt(ledger_start)\n\t\tmessage = result.message\n\t\t_message_visit_id = visit_id\n\t\treturn result',1)
patch('core/day/run_session.gd','if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)','if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)\n\tShopGrowthReadModels.inventory(model, _day)')
patch('core/day/run_session.gd','"hint": "长按1秒送客 · 耗时%d分钟；松开取消。" % customer.terms.reject_minutes','"hint": "长按1秒谢绝买家 · 不耗时；松开取消。" if visit.purpose == "display_buyer" else "长按1秒送客 · 耗时%d分钟；松开取消。" % customer.terms.reject_minutes')
patch('core/day/run_session.gd','_journal_depth -= 1\n\tif not replaying','_journal_depth -= 1\n\tif _day.state.shop_growth_enabled:\n\t\tShopGrowthService.sync(_day.state)\n\t\tif previous != null and previous.shop_growth != _day.state.shop_growth: _pending_checkpoint = true\n\tif not replaying',1)
append('core/day/run_session.gd','''
func growth_command(command: String, detail := "") -> ActionResult:
	return _journal_call("growth_command", [command, detail])

func _impl_growth_command(command: String, detail := "") -> ActionResult:
	var result := ShopGrowthService.perform(_day, command, detail)
	if result.ok:
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
		_persist()
	message = result.message
	return result
''')
# Reuse the actual stock/cash/sale publication path without an external trip.
append('core/inventory/commerce_service.gd','''
static func commit_sale(state: RunState, item: ItemInstance, buyer_id: String, price: int, batch_id := "") -> void:
	var profit := price - item.acquisition_price
	EconomyManager.new().commit(state, price, item.instance_id, "sale/" + item.instance_id, "sale", profit)
	item.ownership_state = "sold"
	var row := {"item_instance_id": item.instance_id, "buyer_id": buyer_id, "night": state.current_night_index, "minute": state.game_minutes, "price": price, "cost_basis": item.acquisition_price, "realized_profit": profit}
	if not batch_id.is_empty(): row["batch_id"] = batch_id
	state.sale_records.append(row)
''')
patch('core/inventory/commerce_service.gd','''	EconomyManager.new().commit(day.state, price, item.instance_id, "sale/" + item.instance_id, "sale", profit)
	item.ownership_state = "sold"
	day.state.sale_records.append({"item_instance_id": item.instance_id, "buyer_id": String(buyer.id), "night": day.state.current_night_index, "minute": day.state.game_minutes, "price": price, "cost_basis": item.acquisition_price, "realized_profit": profit})''','''	commit_sale(day.state, item, String(buyer.id), price)''')
patch('core/inventory/commerce_service.gd','''		EconomyManager.new().commit(day.state, row.price, item.instance_id, "sale/" + item.instance_id, "sale", row.realized_profit)
		item.ownership_state = "sold"
		row.merge({"buyer_id": buyer_id, "night": day.state.current_night_index, "minute": day.state.game_minutes, "batch_id": batch_id})
		day.state.sale_records.append(row)''','''		commit_sale(day.state, item, buyer_id, row.price, batch_id)''')
patch('core/save/investigation_save_codec.gd','if data.get("content_version") != 23 or data.get("save_version") != 23','var version := ShopGrowthService.VERSION if ShopGrowthService.enabled(run) else 23\n\tif data.get("content_version") != version or data.get("save_version") != version')
patch('core/save/investigation_save_codec.gd','(SaveTimeline.UNSETTLED if extended else [])','(SaveTimeline.UNSETTLED if extended or ShopGrowthService.enabled(run) else [])')
patch('core/save/investigation_save_codec.gd','RunSession.new(run, 23, store, catalog)','RunSession.new(run, version, store, catalog)')
patch('core/save/investigation_save_codec.gd','commands["investigation_command"] = [2, 2]','commands["investigation_command"] = [2, 2]\n\tif ShopGrowthService.enabled(run): commands["growth_command"] = [2, 2]')
patch('core/save/investigation_save_codec.gd','session.callv(row.method, args)','var result: ActionResult = session.callv(row.method, args)\n\t\tif row.method == "growth_command" and not result.ok: return null')
patch('core/save/save_library.gd','const MANIFESTS := [','const MANIFESTS := ["res://data/shop_growth_manifest.json", ',1)
patch('core/save/save_library.gd','const LEGACY := {','const LEGACY := {"shop_growth_ten": "user://shop_growth_ten/autosave_v25.json", ',1)
patch('core/save/save_library.gd','const NAMES := {','const NAMES := {"shop_growth_ten": "鬼市当铺 · 当铺成长十夜", ',1)
patch('core/economy/financial_summary.gd','if state.investigation_enabled:','if state.shop_growth_enabled: result.facility_investment = 0\n\tif state.investigation_enabled:',1)
patch('core/economy/financial_summary.gd','match entry.kind:\n','match entry.kind:\n\t\t\t"facility_investment": result.facility_investment -= entry.amount\n',1)
patch('core/inventory/commerce_read_models.gd','const KINDS := {','const KINDS := {"facility_investment": "设施投入", ',1)
patch('core/inventory/commerce_visual_read_models.gd','var subject := "铺面息费"','var subject := "铺面息费"\n\t\tif entry.kind == "facility_investment": subject = ShopGrowthService.NAMES.get(entry.transaction_id.trim_prefix("facility/"), "设施整修")')
patch('ui/night/night_resolution_view.gd','if a.has("preparation_expense"):','if a.has("facility_investment"): rows.append(["设施投入（独立记账）", -a.facility_investment])\n\tif a.has("preparation_expense"):',1)
patch('ui/night/night_resolution_presenter.gd','account["pawn_results"] = []','if _session._day.state.shop_growth_enabled: account.familiar_notes += "\\n查铺记录：已完成%d处核查，材料仍收在修缮与查铺页。" % _session._day.state.shop_growth.exploration.size()\n\t\taccount["pawn_results"] = []',1)
patch('ui/menu/session_menu_view.gd','var _investigation_button: Button','var _growth_button: Button\nvar _investigation_button: Button')
patch('ui/menu/session_menu_view.gd','_investigation_button = Button.new()','_growth_button = Button.new()\n\t_growth_button.text = "修缮与查铺"\n\t_growth_button.name = "ShopGrowthMenuButton"\n\t%RiskButton.get_parent().add_child(_growth_button)\n\t_growth_button.pressed.connect(_route.bind(&"growth"))\n\t_investigation_button = Button.new()',1)
patch('ui/menu/session_menu_view.gd','_investigation_button.visible =','_growth_button.visible = model.get("shop_growth", false) and not model.get("in_room", false)\n\t_investigation_button.visible =',1)
patch('ui/day/day_flow_presenter.gd','_session_menu.render({','_session_menu.render({"shop_growth": ShopGrowthService.enabled(definition), ',1)
patch('ui/counter/counter_screen.gd','const PANEL_TITLES := {','const PANEL_TITLES := {"growth": "修缮与查铺", ',1)
patch('ui/counter/counter_screen.gd','_session = session\n','_session = session\n\tvar growth_panel := ShopGrowthPanel.new()\n\tgrowth_panel.panel_id = &"growth"\n\tgrowth_panel.name = "ShopGrowthPanel"\n\t%DayFlowPanel.get_parent().add_child(growth_panel)\n\tgrowth_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tgrowth_panel.hide()\n\t_flow.register_panel(growth_panel)\n\tgrowth_panel.bind(session)\n',1)
patch('ui/inventory/inventory_presenter.gd','_session.commerce_command(command, target, detail)','if command == "growth_display": _session.growth_command("display", target)\n\telif command == "growth_withdraw": _session.growth_command("withdraw")\n\telse: _session.commerce_command(command, target, detail)')
print('Growth integrations applied')
