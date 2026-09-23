"""Build v32 without rewriting the v31 manifest or its rules."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8-sig'))
def write(path, value):
    target = ROOT/path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

# Shared observation plates always put the two evidence subjects at x=.25/.75.
ROWS = [
('embroidery','展验工具','optics',['框角开裂。','绣面有明显撕裂。'],['查补绣交界的针脚','查衬边内侧的新旧线'],['原针路转折连贯，补绣常在交界多出接针。','掀看衬边，线色与老化应前后相接。'],[['针脚跨过交界，疏密与走向连贯。','衬边内侧与外侧绣线一同旧去。'],['交界处另起了密针，盖住旧针孔。','衬边内侧有一截新线，接在褪色旧线上。'],['花纹表面有印色，针孔与纹样不相应。','背面没有对应绣线，贴衬盖着印色。']]),
('gold_bangle','metal','balance',['镯身局部变形。','镯身有明显断口。'],['查内圈接焊与露底','核衡验与所称规格'],['原有接缝应与旧工式样相合，露底颜色须结合戳记看。','比较尺寸与衡验记录；同样式样不保证同样成色。'],[['内圈色泽连贯，旧接缝与款式相合。','尺寸与衡验记录均落在图录所记范围。'],['内圈焊色偏浅，与低成色旧款的接缝相近。','同样尺寸下的衡验表现，与低成色旧款记录相合。'],['内圈磨处露出异色底材，镀层边缘翘起。','外形相近，衡验表现却与所称规格明显不符。']]),
('gold_watch','clock','clock_deep',['表镜边缘磕裂。','表壳有严重凹损。'],['查机芯固定处改装','核零件与维修记录'],['原配机芯应与固定孔位吻合，不靠另加垫片迁就。','零件式样、编号体系与修理记录须前后对应。'],[['螺孔与机芯座吻合，没有另打孔位。','零件式样与号段、旧维修记录相互对应。'],['机芯座另打孔位，边上垫着新片。','换入机芯的号段与壳款不配，修理单另记换件。'],['简易机芯用填块塞紧，孔位与原厂图完全不同。','号字粗浅，几处机械结构与原厂记录相冲突。']]),
('mantel_clock','clock','clock_deep',['钟壳一角缺损。','钟壳有明显裂损。'],['查报时轮系换件','查机芯安装位置'],['轮系齿形与轴位须配合，修配常留下不同工痕。','原安装孔与钟壳结构对应，迁孔会留下旧孔。'],[['轮系工痕一致，轮齿与轴位配合。','孔位与原厂式样相合，没有迁装旧孔。'],['报时轮中有一枚工痕较新的替换轮。','机芯旁留下封住的旧孔，安装位置曾改动。'],['报时结构与所称型号不符，轮系粗简。','简易机芯靠后来垫木固定，与原式样相冲突。']]),
('pearl_necklace','jewel','optics',['扣环局部变形。','珠线断开，并有缺珠。'],['查孔道深处表层','对照换珠处与邻珠'],['孔道里的表层剥落和胶痕，可以帮助识别涂层或修配。','将可疑珠与邻珠逐粒对照；此法不保证判断天然来源。'],[['孔道边缘表层连续，未见剥落涂层与胶痕。','珠序与旧照相合，邻珠磨耗相近。'],['一粒珠孔道留有重穿时的残胶。','这粒珠与邻珠磨耗不同，旧照中此位另有一粒。'],['孔道深处的薄涂层剥开，露出圆滑底珠。','相邻几粒都有相同涂层边缘，与图录所记冲突。']]),
('jade_pendant','jewel','optics',['吊环局部变形。','玉坠外露处有崩口。'],['查镶爪遮挡处','查补胶与换镶'],['沿镶爪旁转动光线，留意被遮住的细裂是否贯通。','残胶与重复压痕可提示补裂、换镶，不等同于外露磕损。'],[['镶爪后纹理接续，未见贯通裂线。','镶座内侧磨耗一致，没有残胶和重压痕。'],['镶爪后有细裂贯通，外面被金边遮住。','裂线处残留透明胶，镶座内有重复压痕。'],['镶爪后的料中有圆泡，纹理与图录不合。','表层着色聚在镶边，内外料质表现不一致。']]),
('album','展验工具','optics',['页缘有小破口。','册页有撕裂缺页。'],['查款墨与旧损先后','查裱边拼接补纸'],['旧损与款墨的覆盖先后，比纸色深浅更能说明添款。','裱边下拼纸的纤维、画线与旧折须分别核对。'],[['旧折穿过款字，字画在折处一同磨白。','裱边下纸纹接续，画线与旧折自然贯通。'],['题款也已旧去，但画线停顿重描，与临本相近。','纸纹与旧折连续，属于旧临本而非后来添名。'],['浓墨跨过已经破损的折口，字比伤口晚。','裱边压着拼入的题款纸，纤维走向中断。']]),
('porcelain_vase','','optics',['口沿有小磕口。','瓶口有明显裂缺。'],['查瓶颈内侧接胎','查补釉边界'],['接胎可能藏在瓶颈内侧，须沿内壁看整圈接线。','补釉与邻处老化的差别，应顺光观察边界。'],[['内壁胎面连续，瓶颈一圈未见接线。','内外釉层老化相合，光泽过渡自然。'],['内壁瓶颈有细接线，与外侧遮盖位置相对。','接线外侧有一圈补釉，反光与邻处不同。'],['内壁工痕与声称年代式样冲突，胎面过于规整。','做旧色聚在新刻痕里，邻处釉面没有相应老化。']]),
('repeater','clock','clock_deep',['表镜边缘磕裂。','表壳有严重凹损。'],['查报时锤与簧配合','交核壳芯维修记录'],['复杂报时机构的锤、簧与轮系须相互匹配。','原厂式样、壳芯安装与维修记录应能交叉核对。'],[['锤簧与轮系依原式配合，动作衔接。','壳芯号段、安装位与维修记录均能对应。'],['报时锤有新换件，修配位置与原式略有差别。','维修记录写有更换报时件，安装处也留下同位置工痕。'],['机芯缺少原式报时结构，所装简件不能对应。','号段与安装方式均不合原厂记录，凭据也对不上。']]),
('silver_set','metal','balance',['一件银器局部凹瘪。','有断柄或缺盖。'],['查隐蔽补焊露底','交核各件衡验与工艺'],['柄根、盖内的焊口与磨损处，可见拼修或镀层。','整套各件的规格、衡验与工痕应相互照应。'],[['柄根与盖内焊口合旧式，磨处色泽连续。','各件规格与衡验记录成套对应，工痕相合。'],['盖内有后补焊口，一件柄根式样与其他不同。','几件分别对应不同旧套记录，确为后来拼配。'],['柄根磨处露出黄底，薄镀层边缘翘起。','所称银器规格与衡验明显不符，印记也粗浅。']]),
]

def main():
    run = read('data/wealthy/run.json')
    run['records'][0]['id'] = 'precision_ten'
    config = {}
    for short, kit, deepkit, damage, checks, refs, observations in ROWS:
        iid = 'item_luxury_'+('silver_service' if short == 'silver_set' else short)
        config[iid] = dict(kit='display' if kit=='展验工具' else kit, deep_kit=deepkit, damage=['未见明显外伤。']+damage, deep_checks=checks, deep_references=refs, deep_observations=dict(zip(['sound','mended','flawed'],observations)), ambiguous=['细节磨耗使几处特征难以分清，尚不能排除另一种来历。','这一处没有足够清楚的对应关系，还不足以支持定论。'], atlas='res://assets/appraisal_v32/'+short+'.png')
    run['records'][0]['variety']['tiered_appraisal_version'] = 1
    run['records'][0]['variety']['tiered_appraisal'] = config
    write('data/tiered/run.json',run)
    manifest = read('data/wealthy_manifest.json')
    manifest['content_version'] = 32
    manifest['default_run_id'] = 'precision_ten'
    # Retain all v31 definitions and prices; only the run gains the new rules.
    def replace(value):
        if isinstance(value, str): return value.replace('wealthy/run.json','tiered/run.json')
        if isinstance(value, list): return [replace(v) for v in value]
        if isinstance(value, dict): return {k:replace(v) for k,v in value.items()}
        return value
    write('data/tiered_manifest.json',replace(manifest))
if __name__ == '__main__': main()
