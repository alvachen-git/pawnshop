"""One-time authoring source for the opening prototype's data and translations."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
texts = {}
events = []

def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

def write(path, data):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def key(name, text):
    name = "opening." + name
    texts[name] = text
    return name

def choice(id, label, result, flags=(), required=(), excluded=()):
    return dict(id=id, label=label, result=result, minutes=0, grant_flags=list(flags), required_flags=list(required), excluded_flags=list(excluded))

def event(id, title, speaker, body, scene, flags=(), required=(), choices=None, phase="pre_open", **presentation):
    choices = choices or [choice("continue", "继续", body.split("\n")[-1], flags)]
    for c in choices:
        c["label"] = key(id + "." + c["id"] + ".label", c["label"])
        c["result"] = key(id + "." + c["id"] + ".result", c["result"])
    room = phase in ("private_room", "sleep_resolution")
    row = dict(id="evt_intro_" + id, title=key(id + ".title", title), speaker=key(id + ".speaker", speaker), body=key(id + ".body", body),
               kind="anchor", phase=phase, night_min=1, night_max=1, window_start=540 if room else 0, window_end=545 if room else 540,
               priority=1000-len(events), weight=1, max_count=len(choices), cooldown=0, required_flags=list(required), excluded_flags=[], required_items=[], conflicts_with=[], choices=choices,
               presentation=dict(scene=scene, checkpoint=phase != "open", repeat_skip=phase == "pre_open" and scene != "inspection", **presentation))
    events.append(row)
    return row

event("factory_paycut", "上海 · 纱厂", "工头", "高窗下浮着棉尘。工头把钱袋推过来，比往日瘪了一截。\n\n“今天少算你一个时辰。”", "factory")
event("factory_argument", "少算的一个时辰", "你 / 工头", "“机器停的是厂里的，不是我偷懒。”\n\n“不服就别来。外头排着一条街的人等活。”\n\n机器又响起来，压过了你的声音。", "factory")
event("factory_silence", "歇工", "你", "命不好，连争一句都显得多余。\n\n你在墙根坐下，从衣内袋摸出一张旧照片。纸边已经磨得发白。", "photo", ["INTRO_FACTORY_DONE"])
event("manqing_memory", "旧照片 · 新婚帖", "你", "照片里的少年和姚曼卿并肩站着。旁边的婚帖却是新的，朱红纸上写着：\n\n姚曼卿　陆绍廷\n\n夹在帖里的名片印着陆家的商号。她出嫁那天，我连门都没敢去。", "wedding")
event("manqing_money", "上工铃", "你", "不是没话说。是说了又能怎样。\n\n你合上那张婚帖，仍留着照片。\n\n说到底，还是穷。要是我有钱……", "photo", ["INTRO_MANQING_SHOWN"])
event("letter_delivery", "厂门外", "信差", "“你是顾敬堂顾掌柜的远亲？”\n\n“顾掌柜前些日子病故。临终前托人，这封信和钥匙一定要交到你手里。”\n\n钥匙落进掌心。你低声叫了一句：“顾叔……？”", "key", ["INTRO_LETTER_RECEIVED"])
letter = "贤侄：\n\n多年未见，也不知你如今过得如何。\n\n你小时在我柜上帮工，三个月认熟铺里那些银戳，半年以后，谁来当过什么东西，你比账房记得还清。\n\n我这些年见过不少人。眼快的不少，记性好的也不少，真正适合坐柜的人，不多。你算一个。\n\n我没有什么值得留给后人的东西。老城厢这间铺子，连同铺中现货、旧账和楼上的住处，都留给你。\n\n铺里尚有些旧债。你若肯做，不至于还不起。\n\n柜台还是以前那张。钥匙随信。\n\n账可以慢慢算，人不要急着看懂。\n\n——顾敬堂"
event("letter_read", "顾敬堂的信", "顾敬堂", letter, "letter")
event("gu_value", "从前 · 看货", "少年 / 顾敬堂", "你举着一枚旧银元，踮脚把它送到柜上。\n\n“顾叔，这枚是真的。”\n\n顾敬堂挪过灯盏：“真的就一定值钱？”", "memory")
event("gu_people", "从前 · 看人", "顾敬堂", "客人刚走。顾叔把东西转了个面，耐心指给你看。\n\n“东西摆在桌上不会骗人。拿东西来的人会。”", "memory")
event("gu_flashbacks", "从前 · 当票", "顾敬堂 / 少年", "你拿起印章，顾叔轻轻按住你的手。\n\n“印下去，就不是一张纸了。”\n\n“那是什么？”\n\n“是账。”", "stamp", ["INTRO_GU_MEMORY_DONE"])
event("decision", "一间上海的铺面", "你", "你把信里的“铺子、现货、住处”又读了一遍。\n\n“曼卿。”\n\n你握紧钥匙，对着照片说：“等我把铺子做起来，我一定把你迎回来。”", "photo")
event("shop_arrival", "次日黄昏 · 老城厢", "你", "提着旧皮箱，你在老街尽头停下。\n\n铺门比记忆中矮了些。钥匙转动，门轴轻响。柜台还是以前那张。\n\n这回，该自己坐柜了。", "exterior", ["INTRO_SHOP_ARRIVED"], choices=[choice("enter", "推门进铺", "柜台还是以前那张。", ["INTRO_SHOP_ARRIVED"])])
inspection = [
    choice("counter", "旧柜台", "桌角那道浅浅的刻痕还在。小时候，你拿尺子比着身量，偷偷划下了这一笔。", ["INTRO_COUNTER_MARK_SEEN"], excluded=["INTRO_COUNTER_MARK_SEEN"]),
    choice("accounts", "明账", "借据夹在账里，结算日期用墨圈了起来。\n\n{accounts}\n今夜收铺时，先把息费留出来。", ["INTRO_MING_LEDGER_SEEN"], excluded=["INTRO_MING_LEDGER_SEEN"]),
    choice("incense", "财神香炉", "香炉蒙了灰。你拨了拨冷香灰，把炉身扶正。", ["INTRO_INCENSE_NOTICED"], excluded=["INTRO_INCENSE_NOTICED"]),
    choice("ledger", "红黑旧账册", "一本没有题字的旧册，纸色比旁边的账本深。你刚伸出手，门外有人停下脚步。", ["INTRO_YIN_LEDGER_NOTICED"], excluded=["INTRO_YIN_LEDGER_NOTICED"]),
    choice("ready", "坐上柜台", "旧钟敲了六下。门外有人叩门。", ["INTRO_SHOP_INSPECTED"], required=["INTRO_MING_LEDGER_SEEN", "INTRO_YIN_LEDGER_NOTICED"])
]
row = event("shop_inspection", "接手旧铺", "铺内", "把皮箱放下。柜上有两本旧账，香炉里的灰早已冷了。\n\n先翻翻明账，也看看那本红黑旧册。", "inspection", choices=inspection, hotspots=True)
row["excluded_flags"] = ["INTRO_SHOP_INSPECTED"]
event("first_customer", "第一夜 · 新掌柜", "街坊妇人 / 你", "“顾掌柜不在了？”\n\n“从今日起，我坐柜。”\n\n妇人把银簪放上桌：“那你给我看看这个。”\n\n先点桌上银簪，选「观察」，再用放大镜快速鉴看。也可以向客人问来历，想好价钱后再开口。", "customer", ["INTRO_FIRST_CUSTOMER_STARTED"], phase="open")
row = event("first_trade", "第一笔账", "柜前", "钱货已经点清，凭据收在手边。\n\n你看着印泥留在纸上的红痕，想起顾叔按住你手的那一刻。\n\n收下的货还占着本钱。去「库存」选合适的买家，卖出后才知道这笔生意赚了多少。", "stamp", ["INTRO_FIRST_TRADE_DONE"], required=["INTRO_FIRST_CUSTOMER_STARTED"], phase="open", required_purchases=1)
row["night_max"] = 3
room_choices = [
    choice("letter", "书桌 · 放好遗信", "你把顾叔的信抚平，放进书桌抽屉。想念时，还可以再取出来读。", ["INTRO_LETTER_STORED"], excluded=["INTRO_LETTER_STORED"]),
    choice("photo", "摆上姚曼卿的照片", "你把照片靠在砚台旁。照片里，两个人仍并肩站着。", ["INTRO_MANQING_PHOTO_PLACED"], excluded=["INTRO_MANQING_PHOTO_PLACED"]),
    choice("lamp", "看命灯", "火稳，色暖。", ["INTRO_LIFE_LAMP_SEEN"], excluded=["INTRO_LIFE_LAMP_SEEN"]),
    choice("mirror", "看旧镜", "旧镜一面，照出你赶了一天路的疲色。", ["INTRO_MIRROR_SEEN"], excluded=["INTRO_MIRROR_SEEN"]),
    choice("settled", "收拾妥当", "铺门已经落闩。床上的被褥是干净的，累了便歇下吧。", ["INTRO_ROOM_SEEN"], required=["INTRO_LETTER_STORED", "INTRO_LIFE_LAMP_SEEN"])
]
row = event("room_first_night", "楼上 · 寝屋", "你", "03:00。铺门落闩，你提着灯走上楼。\n\n旧书桌、床铺，还有一面普通的镜子。先把信放好，再看看灯。照片也可以摆在桌上。", "room", choices=room_choices, phase="private_room", hotspots=True)
row["excluded_flags"] = ["INTRO_ROOM_SEEN"]
event("sleep_first_night", "灯下", "你", "你躺下来。室内暗了些，命灯仍亮着。\n\n“明天多接几单。先把这铺子做起来。”\n\n楼下木头轻轻响了一声，再没有别的动静。", "sleep", ["INTRO_FIRST_SLEEP", "INTRO_COMPLETE"], phase="sleep_resolution")

run = copy.deepcopy(read("data/runs/p0_room.json")["records"][0])
run.update(id="opening_v01", initial_cash=100, event_ids=[e["id"] for e in events], flag_ids=list(dict.fromkeys(f for e in events for c in e["choices"] for f in c["grant_flags"])), buyer_ids=["buyer_recycler", "buyer_collector", "buyer_silversmith"], ghost_rule_ids=["weeping_mirror"], mirror_encounters=[], trade_scenarios=[])
run["customer_slots"] = [s for s in run["customer_slots"] if s["item_id"] != "item_weeping_mirror"]
first = run["customer_slots"][0]
first.update(id="intro_trade_01", item_id="intro_silver_hairpin", customer_id="intro_neighbor", variant_id="", tutorial=dict(min_quote_rounds=4, min_patience=4))
run["trade_scenarios"] = [dict(id="intro_trade_01", slot_id=first["id"], item_id=first["item_id"], variant_ids=["mended"], situations=["ordinary"], reactions=["admit"], introduction="妇人把银簪放在柜上：“家里的旧物。掌柜给个公道价。”", questions=[dict(id="origin", prompt="问银簪的来历", answers={"default":"“家里用过的老东西。簪尾修过一回，你照实看。”"}, minutes=5, requires_questions=[], requires_clues=[], pressure_clue="", patience_cost=0)], images=[dict(id="front", label="正面", path="res://assets/opening/hairpin.svg", requires_clues=[]), dict(id="back", label="背面", path="res://assets/opening/hairpin.svg", requires_clues=[]), dict(id="repair", label="簪尾旧修", path="res://assets/sample/hairpin_seam.svg", requires_clues=["condition_mended"])], benefit_groups={"condition_mended":"repair"}, concession_question="", concession_amount=0, concession_minutes=5, urgent_wait_minutes=180)]
item = copy.deepcopy(next(i for i in read("data/items/items_v11.json")["records"] if i["id"] == "item_silver_hairpin"))
item.update(id="intro_silver_hairpin", base_value=25, visual_asset_id="placeholder.silver_hairpin", description="簪头刻花，银色被磨得温润；簪尾隐约有一道旧修痕。")
item.pop("provenance", None)
item["appraisal_actions"][0]["label"] = "观察银簪"
item["appraisal_actions"][1]["label"] = "快速鉴看 · 戳记与旧修"
next(c for c in item["clues"] if c["id"]=="form")["text"] = "银色温润，簪头刻花已磨浅，簪尾可见细微旧修痕。"
customer = copy.deepcopy(read("data/customers/customers_v11.json")["records"][0])
customer.update(id="intro_neighbor", transaction_modes=["sell"], pawn_terms_id="", item_pool=[item["id"]], patience=2, max_quote_rounds=2)
customer.pop("belittle", None)
customer["counter_terms"].update(display_name="街坊妇人", introduction="“顾掌柜不在了？……那你给我看看这个。”", wait_minutes=180, ask_multiplier=1.12, reserve_ratio=0.75, counter_step=3)
customer["questions"] = [dict(id="origin", prompt="问来历", answer="家里用过的旧物，簪尾修过一回。", minutes=5)]
buyers = read("data/buyers/buyers_v11.json")["records"][:2]
buyers.append(dict(id="buyer_silversmith", display_name="街口银楼", channel="regular", categories=["jewelry"], value_multiplier=1.0, night_min=1, night_max=3, window_start=0, window_end=540, action_minutes=10, capacity_per_night=2))
write("data/opening/events.json", dict(schema_version=1, records=events))
write("data/opening/run.json", dict(schema_version=1, records=[run]))
write("data/opening/items.json", dict(schema_version=1, records=[item]))
write("data/opening/customers.json", dict(schema_version=1, records=[customer]))
write("data/opening/buyers.json", dict(schema_version=1, records=buyers))
sources = [("runs", "opening/run.json"), ("items", "items/items_v11.json"), ("items", "opening/items.json"), ("customers", "customers/customers_v11.json"), ("customers", "opening/customers.json"), ("buyers", "opening/buyers.json"), ("pawn_terms", "pawn_terms/terms_m3.json"), ("events", "opening/events.json"), ("ghost_rules", "ghost_rules/rules_m5.json")]
write("data/opening_manifest.json", dict(content_version=12, default_run_id=run["id"], sources=[dict(kind=k, path="res://data/"+p) for k,p in sources]))
key("letter.permanent", letter)
key("room.photo", "照片里，两个人仍并肩站着。你用指腹抹去纸面上的一点灰。")
key("skip", "从抵达当铺开始")
key("save_exit", "保存并退出")
key("stamp", "盖章 · 收好凭据")
key("stamp_done", "有几分顾掌柜的样子。")
write("data/opening/text_zh_CN.json", texts)
