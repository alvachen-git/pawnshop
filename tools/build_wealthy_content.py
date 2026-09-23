"""Author the v31 data bundle; never rewrite the preserved v30 catalog."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))

def write(path, data):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# id, name, category, knowledge, values, two checks, two reference passages,
# observations for sound / mended / flawed. These are evidence, not verdicts.
GOODS = [
    ("embroidery", "精品绣屏", "textile", "textile", [360,240,60],
     ["查看针路与接色", "侧看背衬与拼补"],
     ["旧绣谱记：针脚随花叶转向，深浅丝线交错接色；印染仿绣的颜色常越过针孔。", "装屏手记：原衬经纬接续，旧磨痕随折线延伸；补衬常另起一层。"],
     [["花瓣转折处针脚随势回转，几色丝线逐层交错。","背衬经纬接续，边角磨痕沿原折线延伸。"], ["花叶针路细密，接色与绣谱相近。","背后新添一块衬布，接线横过旧折，边花已有褪色。"], ["花叶的深色漫过几处针孔，凸起的丝线只勾了外轮廓。","背面只有轮廓走线，正面大块颜色找不到相应绣线。"]]),
    ("gold_bangle", "赤金手镯", "jewelry", "metal", [440,330,70],
     ["对照戳记与称重记录", "查看内圈与接焊"],
     ["金铺样册把赤金与低成色旧款分列，须将戳式、尺寸与称重记录合看，单凭颜色不能定成色。", "修金手记：焊口的色与纹路会中断；镀件深磨处可能露出异色底料。"],
     [["戳式与赤金旧款一栏相合，同尺寸称重记录也能对应。","内圈几处深磨痕颜色连续，合口处未见另焊。"], ["重量相近，戳字末笔却与样册中的低成色旧款相合。","合口有一线焊色，镯身仍厚实，未见镀层起皮。"], ["字号的笔画挤在一起，重量比同尺寸旧款轻了一截。","内圈深磨处露出青黄底，边缘薄层翘起。"]]),
    ("gold_watch", "金壳怀表", "watches", "watch", [500,350,100],
     ["对照机芯与壳款", "试走时并查看换件"],
     ["钟表图册：此式壳款对应三桥机芯，厂记刻在桥板内侧。壳与芯须分开核对。", "修表簿：同批螺钉磨耗相近；新旧换件须记明，走时正常也不等于原装。"],
     [["三块桥板的排列与图册相合，壳内款式也能对应。","上弦后走动平稳，螺钉的色泽与磨耗接近。"], ["壳款与三桥式相合，桥板边缘却多了一处改装孔。","两枚螺钉明显较新，走动时偶有停顿。"], ["壳上刻着同样店名，芯内却是图册另一种廉价结构。","表耳磨出黄铜底，机芯垫着一圈不合尺寸的薄片。"]]),
    ("mantel_clock", "进口座钟", "watches", "watch", [600,360,120],
     ["对照机芯与型号", "试报时并查看钟壳"],
     ["进口钟样册：这一型号用双发条结构，厂记与底座编号相互对应。", "修钟簿：报时应与指针时位相合；补木、换锤与重新钻孔各有接缝。"],
     [["双发条与齿轮位置能和样册对应，底座编号清楚。","报时与指针相合，钟壳木纹在边角连续。"], ["双发条结构相合，固定架上却有移位钻孔。","报时慢了一拍，钟壳一角补木，锤杆也换过。"], ["铭牌写着进口厂名，机芯却只有简易单发条。","报时装置未接入齿轮，铭牌下留着新钉孔。"]]),
    ("pearl_necklace", "珍珠项链", "jewelry", "jade", [440,280,60],
     ["查看孔口与表层", "对照珠序与旧照"],
     ["珠饰手记：留意孔口积涂与剥落，逐粒比较表层；仅此不能保证区分天然珠和养殖珠。", "旧照图录：按主珠位置、粒径次序和扣形比对，绳线换新不等于珠子全换过。"],
     [["孔口未见积涂与剥皮，各珠表面有细微而不同的纹理。","主珠位置、粒径次序与旧照相合，扣头磨痕连续。"], ["大部分珠粒纹理相近，靠扣处三粒表层格外平整。","靠扣三粒的大小次序与旧照不同，扣头也换成了新式。"], ["数粒孔口积着一圈涂层，缺口下露出均匀底珠。","整串粒径过分齐整，旧照里的主珠位置已经不见。"]]),
    ("jade_pendant", "金镶玉坠", "jewelry", "jade", [520,340,80],
     ["透光查看纹理", "查看镶口与接合"],
     ["玉器手记：先看内部纹理与可见裂隙，气泡和模线只能作疑点，须与镶口证据合看。", "镶嵌图录：原镶爪位与纹饰配合；遮住裂缝的加宽爪、胶线须另记。"],
     [["内部纹理疏密有变化，透光处未见贯穿裂线。","镶爪与纹饰位置相合，爪根旧磨痕连续。"], ["坠身仍有自然纹理，一条亮线延伸到镶口下面。","一只镶爪加宽，爪下留有透明胶线。"], ["内部几处圆泡连在一起，侧边隐约有一道直模线。","金色表层在爪尖脱落，露出的接边正与模线相接。"]]),
    ("album", "名家册页", "stationery", "painting", [560,280,70],
     ["对照笔法与题款", "查看纸墨与装裱"],
     ["周问石摹存：转笔收放相接，题款末笔略回锋；临本常沿轮廓重描。", "装裱手记：旧折应同时穿过纸墨；新墨跨过旧破口，须留意后添款。"],
     [["山石转笔收放连贯，款字末笔有回锋。","旧折穿过字画，磨白处相接，裱边旧色一致。"], ["山石轮廓相似，转角有停笔重描，款字缺少回锋。","纸墨一同旧去，裱边没有新添款留下的断层。"], ["几处用笔直硬，款字靠描边拼出形状。","浓墨盖住已磨白的破口，裱边却仍保留旧损。"]]),
    ("porcelain_vase", "古瓷小瓶", "porcelain", "porcelain", [600,300,90],
     ["对照器形底足与款识", "侧看口沿釉面与接缝"],
     ["藏瓷图录：瓶肩比例、足墙修削与款式须彼此相合；有旧款不能单独证明年代。", "修瓷手记：口沿补釉、瓶颈拼接的光泽常与邻处不同，应顺侧光逐段看。"],
     [["肩腹比例与图录相合，足墙修削痕和款式相称。","口沿釉光连续，瓶颈转折处没有横向接线。"], ["器形与足款相合，足底旧磨痕仍在。","侧光下瓶颈有一圈细接线，口沿补釉反光发闷。"], ["底款照着旧字写，足墙却厚直，肩腹比例也偏离图录。","釉下的做旧色只积在几道新刻划痕里，磨痕互不接续。"]]),
    ("repeater", "报时金怀表", "watches", "watch", [1200,900,180],
     ["对照复杂机芯图录", "试报时并核维修记录"],
     ["表厂图录：报时轮系与双音簧的位置固定，须连同桥板和壳内款式逐处比对。", "维修单：换簧应有日期、部件与壳号；仅有一纸店章不能替代功能查验。"],
     [["报时轮系、双音簧与桥板位置都能对应图录。","拨动报时后音序相合，维修记录所列壳号与原物相符。"], ["轮系位置相合，一根音簧的固定口有新修痕。","报时正常，维修单记过一次换簧，日期与部件痕迹相合。"], ["桥板外形近似，图录所示报时轮系的位置却空着。","拨杆只带动一片响簧，壳内号与所谓维修单不同。"]]),
    ("silver_service", "西洋银器套件", "metal", "metal", [1400,980,210],
     ["对照印记与整套式样", "查看拼配补焊与磨损"],
     ["银器样册：成套壶、杯、盘的厂记与纹边应相互对应；同为银器也可能来自不同套。", "银工手记：深磨处、焊缝和壶嘴内沿分开看，镀层脱落与实银补焊不能混作一事。"],
     [["壶杯盘的厂记和纹边相互对应，尺寸也合一套。","深磨处颜色连续，壶嘴内沿与杯底未见补焊。"], ["壶与盘同式，两只杯的厂记和纹边却属于另一套。","壶嘴有补焊线，各件深磨处仍未见镀层露底。"], ["印记浅浅重复压在同一位置，纹边细节模糊。","杯底与壶把深磨处露出红黄底，表层银色在边沿脱落。"]]),
]

PROFILES = [
    ("silk", "绸缎庄东家", "账上赊欠还没收齐，新货的订金却等不得。拿两件私藏来周转，货好不好，您照实看。", ["embroidery","gold_bangle"],60,4,4,1,115,85,0,80,80,[65,25,10],30,"文绣","asset.customer_teahouse"),
    ("factory", "机器厂老板", "买主的货款还没结，工钱和原料款先到了日子。货请您挑要紧的看，工头还在门外等。", ["gold_watch","mantel_clock"],40,3,2,1,110,95,65,90,50,[50,40,10],25,"振业","asset.customer_watchmaker"),
    ("opera", "梨园名角", "戏院的场钱、班里人的开销都要先付。私物暂且拿来周转，请垫好软布再看。", ["pearl_necklace","jade_pendant"],60,4,3,2,115,90,0,90,80,[60,30,10],25,"玉笙","asset.customer_seamstress"),
    ("antique", "古玩行掌柜", "外埠有一批旧货等着接，手边银根紧。眼前这件您按图录看，旧伤与年代可得分清。", ["album","porcelain_vase"],70,5,3,2,130,100,0,60,20,[35,35,30],20,"怀古","asset.customer_scholar"),
    ("comprador", "洋行大买办", "这笔私人买卖，不能从洋行账上支。汇款尚在路上，先拿私藏周转；票据请当面核清。", ["repeater","silver_service"],50,3,2,2,115,95,75,90,80,[65,25,10],0,"伯衡","asset.customer_agent"),
]

def main():
    items, profiles, customers, appraisal = [], {}, [], {}
    template = read("data/goods_expertise/items.json")["records"][0]
    customer_template = read("data/goods_expertise/customers.json")["records"][0]
    for short, name, category, topic, values, checks, refs, observations in GOODS:
        iid = "item_luxury_" + short
        item = copy.deepcopy(template)
        for field in ["provenance", "expertise"]: item.pop(field, None)
        item.update(id=iid, name_key=f"item.{iid}.name", display_name=name, description=f"客人将{name}安放在柜上，等你掌眼。", category=category, base_value=values[0], unknown_min=values[2], unknown_max=values[0], tags=[category,"luxury"], visual_asset_id="luxury."+short, appraisal_actions=[], clues=[], possible_variants=[])
        for index, variant in enumerate(["sound","mended","flawed"]):
            item["possible_variants"].append(dict(id=variant,true_value=values[index],weight=1,clue_ids=[]))
        items.append(item)
        # A pair identifies BOTH identity and condition; matching is a player decision.
        identity = ["original","original","imitation"]
        conditions = ["intact","altered","intact"]
        if short == "album": identity[1] = "copy"; conditions[1] = "intact"
        if short == "gold_bangle": identity[1] = "lower_grade"; conditions[1] = "altered"
        appraisal[iid] = dict(topic="luxury_"+topic,checks=checks,references=refs,observations=dict(zip(["sound","mended","flawed"],observations)),identity=dict(zip(["sound","mended","flawed"],identity)),condition=dict(zip(["sound","mended","flawed"],conditions)))
    for short,name,intro,pool,wait,rounds,patience,false_cost,ask,reserve,need,pawn,redeem,variants,weight,given,portrait in PROFILES:
        cid = "customer_wealthy_" + short
        profiles[cid] = dict(pawn_percent=pawn,weights=variants,weight=weight,asking_percent=ask,reserve_percent=reserve,funding_percent=need)
        customer = copy.deepcopy(customer_template)
        customer.pop("belittle",None)
        customer.update(id=cid,name_key=f"customer.{cid}.name",portrait_asset_id=portrait,identity_tags=["wealthy",short],wealth_band="ultra_wealthy" if short == "comprador" else "wealthy",urgency_range=[.3,.9] if short == "factory" else [.2,.6],patience=patience,max_quote_rounds=rounds,alertness=.9 if short in ["antique","comprador"] else .6,item_pool=["item_luxury_"+i for i in pool],pawn_redemption_chance=redeem,pawn_terms_id="sample_three_redeem")
        customer["counter_terms"].update(display_name=name,introduction=intro,wait_minutes=wait,ask_multiplier=ask/100,reserve_ratio=reserve/ask,counter_step=1,false_pressure_cost=false_cost)
        customer["persona"] = dict(names=[given,"仲文","季安","云卿"],origin=intro,introduction=intro,redeem="钱已筹齐，这是当票。劳烦核清原物，替我包好。",extend="周转还差些时日，照票上的规矩办吧。",pawn_background={"silk":"铺里的应收账款尚未入柜，东家盼着结账后取回私物。","factory":"工厂的收款时日说不准，能否如期取赎还要看买主。","opera":"几场戏唱完才能结钱，名角仍惦记着自己的首饰。","antique":"他对抵来的货并不恋栈，手头另一笔生意更要紧。","comprador":"账面虽有产业，汇款能否按时到仍未可知。"}[short],completed="他点清银元，将收据收进衣袋。",refused="他将价钱又说了一遍：‘这个数还办不成。’",rejected="他收好包裹：‘那就改日再谈。’",timed_out="他看了看时辰，合上包裹离开柜前。",false_pressure="他收回目光：‘这个说法，凭据还不够。’")
        customer["questions"] = [dict(id="origin",prompt="问这件私藏的来历",answer="是从旧藏里取来的。留下的记录我都带了，年深日久的事，还请您照实物看。",minutes=5),dict(id="funds",prompt="问这笔钱的用途",answer=intro,minutes=5)]
        customers.append(customer)
    run = read("data/unified/run.json")
    record = run["records"][0]
    record["id"] = "wealthy_ten"
    record["variety"]["luxury"] = dict(version=1,profiles=profiles,items=appraisal)
    manifest = read("data/unified_manifest.json")
    manifest.update(content_version=31,default_run_id="wealthy_ten")
    manifest["sources"][0]["path"] = "res://data/wealthy/run.json"
    manifest["sources"] += [dict(kind="customers",path="res://data/wealthy/customers.json"),dict(kind="items",path="res://data/wealthy/items.json")]
    write("data/wealthy/run.json",run)
    write("data/wealthy/items.json",dict(schema_version=1,records=items))
    write("data/wealthy/customers.json",dict(schema_version=1,records=customers))
    write("data/wealthy_manifest.json",manifest)

if __name__ == "__main__": main()
