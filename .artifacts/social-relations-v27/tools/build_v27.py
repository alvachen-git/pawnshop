from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf-8-sig')
def write(p,s):
    (ROOT/p).parent.mkdir(parents=True,exist_ok=True)
    (ROOT/p).write_text(s,encoding='utf-8')
def edit(p,a,b):
    s=read(p)
    assert a in s,(p,a[:100])
    write(p,s.replace(a,b))
def data(p): return json.loads(read(p))
def dump(p,v): write(p,json.dumps(v,ensure_ascii=False,indent=2)+'\n')

edit('project.godot','V26-SocialRelations.1','V27-CoatsAndPlaque.1')
edit('project.godot','GhostMarketPawnshop-SocialRelations','GhostMarketPawnshop-SocialRelations-v27')
edit('scenes/start.tscn','autosave_v26','autosave_v27')
edit('core/save/save_library.gd','social_relations_ten/autosave_v26','social_relations_ten/autosave_v27')
edit('core/social/social_rules.gd','const VERSION := 26','const VERSION := 27')
edit('core/social/social_rules.gd','"favor": false','"plaque_awarded": false, "intimidations": []')
edit('core/social/social_rules.gd','\tif key == "military" and int(state.social.military) <= -20', '\tif key == "military": MilitaryPlaque.award(state)\n\tif key == "military" and int(state.social.military) <= -20')
rules=data('data/social_relations/rules.json')
rules['contracts']=[{'id':'coats','item':'item_cotton_coat','name':'采购棉袄','quantity':3,'reward':50,'duration':0,'delta':6,'tier':-100}]
rules['coat']={'chance_percent':20,'sound_percent':70,'sound_value':15,'worn_value':10}
rules['plaque']={'threshold':30,'price_percent':90,'reputation_cost':1}
dump('data/social_relations/rules.json',rules)
for p in ['data/social_relations_manifest.json','data/content_manifest.json']:
    m=data(p); m['content_version']=27
    m['sources'].append({'kind':'items','path':'res://data/social_relations/coats.json'})
    dump(p,m)

coat={'id':'item_cotton_coat','display_name':'棉袄','description':'靛蓝布面的旧棉袄，盘扣齐整。棉胎厚薄与里衬磨损，还须上手细看。','category':'textile','base_value':15,'unknown_min':8,'unknown_max':17,
 'possible_variants':[{'id':'sound','true_value':15,'weight':7,'clue_ids':['form','sound']},{'id':'worn','true_value':10,'weight':3,'clue_ids':['form','worn']}],
 'clues':[{'id':'form','text':'盘扣、衣襟都在，针脚是寻常家用做法。','min_value':8,'max_value':17,'leverage':0,'judgement':'unknown'}, {'id':'sound','text':'棉胎蓬松，里衬结实，没有虫蛀与大片破口。','min_value':14,'max_value':16,'leverage':0,'judgement':'sound'},{'id':'worn','text':'袖口磨白，棉胎略薄，缝口仍牢，添件里衣还能御寒。','min_value':9,'max_value':11,'leverage':5,'judgement':'damaged'}],
 'appraisal_actions':[{'id':'observe','label':'识货：查看衣襟盘扣','minutes':5,'required_tool':'','requires_clues':[],'reveals':['form']},{'id':'inspect','label':'验货：摸棉胎、翻里衬','minutes':5,'required_tool':'','requires_clues':['form'],'reveals':['sound','worn']}],
 'name_key':'item.cotton_coat.name','type':'normal','tags':['textile','coat'],'value_variance':0.1,'liquidity':0.8,'valuation_rules':[],'sell_channels':['regular'],'buyer_tags':[],'ghost_rule_id':'','visual_asset_id':'social.cotton_coat'}
dump('data/social_relations/coats.json',{'records':[coat]})

p='core/social/military_service.gd'
s=read(p)
s=s.replace('驻军的孙大元','军阀经办孙大元').replace('疏通需%d银元，也可托他还上先前的一次人情。','疏通需%d银元，须在开铺前办妥。')
s=s.replace('state.social.introduced = true','state.social.introduced = true\n\t\tMilitaryPlaque.award(state)')
s=s.replace('static func contract_template(state: RunState)', 'static func contract_template(_state: RunState)')
a=s.index('\tvar chosen: Dictionary = SocialRules.config().contracts[0]'); b=s.index('\nstatic func claim_for',a)
s=s[:a]+'\treturn SocialRules.config().contracts[0].duplicate(true)\n'+s[b:]
s=s.replace('if not contract.is_empty() or quiet(int(state.social.last_contract), state.current_night_index, 2): return "前一笔尚未办完，或下一份采购单还没送来。"','if not contract.is_empty(): return "先前接下的棉袄还没交齐。"')
s=s.replace('\n\t\t\tif state.phase != &"pre_open": return "采购单须在开铺前接洽。"','')
a=s.index('\t\t\tvar item := InventoryManager.new().find(state, detail)',s.index('\t\t"deliver":')); b=s.index('\n\t\t"pay",',a)
s=s[:a]+'''\t\t\treturn CoatProcurement.delivery_reason(state, detail)
'''.rstrip()+s[b:]
s=s.replace('"pay", "refuse", "favor", "close"','"pay", "refuse", "close"').replace('["pay", "favor", "close"]','["pay", "close"]')
s='\n'.join(line for line in s.split('\n') if 'command == "favor"' not in line and 'if social.favor:' not in line and 'social.favor = true' not in line)
s=s.replace('not state.social.favor and int(state.social.military) < 20','int(state.social.military) < 20')
s=s.replace('order.merge({"accepted": n, "due": n + int(order.duration), "number": social.contracts.size() + 1})','order.merge({"accepted": n, "due": 0, "number": social.contracts.size() + 1})')
s=s.replace('text = "%s已接下，第%d夜夜末前交齐，货款%d银元。" % [order.name, order.due, order.reward]','text = "棉袄采购已接下。自有棉袄三件一并交货，付50银元，不限期限。"')
s=s.replace('text = "你把采购单退回，经办人说过几日有合适的再来问。"','text = "你暂且谢绝。孙大元收回单子：‘哪天有货，再来找我。’"')
a=s.index('\t\t"deliver":',s.index('static func perform')); b=s.index('\n\t\t"pay",',a)
s=s[:a]+'''\t\t"deliver":
\t\t\tCoatProcurement.deliver(state, detail)
\t\t\ttext = "孙大元点清三件棉袄，付了50银元：‘这批收妥。还有货，可以再接一单。’"
'''.rstrip()+s[b:]
a=s.index('static func settle('); b=s.index('\nstatic func suspend',a)
s=s[:a]+'static func settle(_state: RunState) -> void:\n\tpass # Cotton-coat orders have no deadline.\n'+s[b:]
s=s.replace('\n\tif not state.social.contract.is_empty(): state.social.contract.due += 1','')
write(p,s)

p='core/social/social_read_models.gd';s=read(p)
s='\n'.join(l for l in s.split('\n') if 'if social.favor:' not in l and 'button(model, day, "favor"' not in l)
s=s.replace('；也可以请他还上先前那次人情','')
a=s.index('\tvar order: Dictionary = social.contract');b=s.index('\n\tbutton(model, day, "gift"',a)
s=s[:a]+'''\tvar order: Dictionary = social.contract
\tmodel.body += "\\n\\n采购棉袄 · 自有棉袄%d／3\\n三件一并交货，货款50银元，期限不限。" % CoatProcurement.stock(state).size()
\tif order.is_empty(): button(model, day, "accept_contract", "接下采购单")
\telse: button(model, day, "cancel_contract", "退回已经接下的采购单")
'''.rstrip()+s[b:]
write(p,s)

p='core/social/faction_book_models.gd';s=read(p)
s=s.replace('if social.favor: model.body += "\\n孙大元留过话：有一件事可以托他说情。"','if social.plaque_awarded: model.body += "\\n已获军方照应牌，挂在铺中；普通收购与活当可借牌压价一成，但会损伤口碑。"')
a=s.index('\tvar order: Dictionary = social.contract');b=s.index('\nstatic func pending_section',a)
s=s[:a]+'''\tvar offered: bool = social.contract.is_empty()
\tmodel.title = "采购棉袄" + ("" if offered else " · 已接")
\tvar stocks := CoatProcurement.stock(state)
\tmodel.body = "" if stocks.size() >= 3 else "还缺%d件自有棉袄；在当物不能交货。" % (3 - stocks.size())
\tmodel.fields = [["货物", "棉袄 ×3 · 自有棉袄%d／3" % stocks.size()], ["要求", "三件一并交货，完整或旧而可穿均可"], ["期限", "不限"], ["货款", "50银元"]]
\tif SocialRules.closed(state): model.body = "今夜停接新生意，暂不交货。采购单继续保留。"
\tif offered:
\t\tSocialReadModels.button(model, day, "accept_contract", "接下采购单")
\t\tSocialReadModels.button(model, day, "decline_contract", "暂不接单")
\telse:
\t\tmodel["stock"] = stocks.map(func(item: ItemInstance) -> Dictionary: return {"id":item.instance_id, "label":"货签%d · 棉袄 · 成本%d银元" % [state.inventory_instances.find(item) + 1, item.acquisition_price]})
\t\tSocialReadModels.button(model, day, "deliver", "交付所选三件棉袄", "[]")
\t\tSocialReadModels.button(model, day, "cancel_contract", "退回已经接下的采购单")
\treturn model
'''+s[b:]
write(p,s)

edit('core/day/opening_preparation.gd','\tGoodsExpertise.attach(rows, run, state.run_seed)','\tCoatProcurement.overlay(state, rows)\n\tGoodsExpertise.attach(rows, run, state.run_seed)')
edit('core/customer/variety_service.gd','\t\tvisit.trade.opening_price = maxi(1, roundi(item.base_value * customer.terms.ask_multiplier))','\t\tvar opening_value := float(item.base_value)\n\t\tif item.id == CoatProcurement.ITEM: opening_value = float(SocialRules.config().coat.sound_value if row.variant_id == "sound" else SocialRules.config().coat.worn_value)\n\t\tvisit.trade.opening_price = maxi(1, roundi(opening_value * customer.terms.ask_multiplier))')
edit('core/trade/counter_service.gd','\t\t"belittle":\n\t\t\tif customer.belittle', '\t\t"intimidate":\n\t\t\tif not detail.is_empty() or amount != 0: return "借牌压价不接受另填报价。"\n\t\t\treturn MilitaryPlaque.reason(day.state, visit)\n\t\t"belittle":\n\t\t\tif customer.belittle')
edit('core/trade/counter_service.gd','\t\t"belittle": message = BelittleService.apply(visit, customer)','\t\t"intimidate": message = MilitaryPlaque.intimidate(day.state, visit)\n\t\t"belittle": message = BelittleService.apply(visit, customer)')
edit('core/trade/counter_read_models.gd','\tif not customer.belittle.is_empty():','\tif state.social_enabled and state.social.plaque_awarded and ReputationService.eligible(state, visit):\n\t\tmodel.trade.buttons.append(_button(day, service, visit, "intimidate", "", "借军方牌子压价 · 让价10%"))\n\t\tmodel.trade.body += "\\n借牌压价每位客人限一次，会损伤口碑。"\n\tif not customer.belittle.is_empty():')
edit('ui/art/counter_visual_catalog.gd','static func _painted_front(asset: String) -> String:\n','static func _painted_front(asset: String) -> String:\n\tif asset == "social.cotton_coat": return "res://assets/social_v27/cotton_coat.png"\n')
edit('ui/art/counter_visual_catalog.gd','\tvar result: Array = []\n\tvar family:', '\tvar result: Array = []\n\tif visual.get("item_asset", "") == "social.cotton_coat": return [{"id":"front", "label":"棉袄", "path":"res://assets/social_v27/cotton_coat.png"}]\n\tvar family:')
print('v27 base changes applied')
