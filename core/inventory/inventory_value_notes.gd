extends RefCounted

# Inventory copy is keyed to revealed evidence, never the hidden physical variant.
# Confirmed observations precede preliminary ones so repeated inspections yield one note.
# Full evidence remains available in the appraisal view and in saved history.
const NOTES := {
	"item_blue_bowl": [
		["intact", "釉面完整，未见修补。"],
		["repair", "有补釉修补。"],
		["condition_chipped", "口沿小磕，未见胶修。"]],
	"item_brass_holder": [
		["brass_core", "铜料里外一致。"],
		["iron_core", "包铜铁芯。"],
		["condition_loose", "底座松动。"],
		["attracts", "内有铁料，不能按整铜算价。"]],
	"item_silver_hairpin": [
		["sound", "银色里外一致，未见镀层。"],
		["flaw", "露出黄底，疑为镀银。"],
		["condition_mended", "簪身有补焊。"],
		["secondary_mended", "接处隆起，疑有补焊。"]],
	"item_pocket_watch": [
		["sound", "走时平稳，机芯未见明显磨损。"],
		["flaw", "走时不稳，轴孔磨损，需修。"],
		["condition_worn", "表壳磨损，走时正常。"],
		["secondary_worn", "表壳明显磨损，走时待验。"]],
	"item_inkstone": [
		["sound", "天然石纹，质地细密。"],
		["flaw", "石眼后添色点。"],
		["condition_chipped", "砚边缺角，未见填补。"],
		["secondary_flawed", "边角色层剥落，疑有着色。"],
		["secondary_chipped", "砚边缺角。"]],
	"item_clay_teapot": [
		["sound", "胎面完整，壶把未见修补。"],
		["flaw", "壶把胶修，壶腹有裂。"],
		["condition_replaced_lid", "壶盖非原配，合口有隙。"],
		["secondary_replaced_lid", "壶盖与壶身不合，疑为后配。"]],
	"item_silk_panel": [
		["sound", "经纬完整，绣线未见大片断裂。"],
		["flaw", "水渍入纤维，绣线脆断。"],
		["condition_faded", "绣面褪色，经纬尚完整。"],
		["secondary_flawed", "边角水渍，绣线易散。"],
		["secondary_faded", "绣面褪色，经纬待查。"]],
	"item_fountain_pen": [
		["sound", "笔尖完好，供墨槽通畅。"],
		["flaw", "笔尖歪裂，供墨槽堵塞。"],
		["condition_replacement_nib", "更换笔尖，装配正常。"],
		["secondary_replacement_nib", "笔尖厂记不符，疑为更换。"]],
	"item_silver_ring": [
		["sound", "银色里外一致，未见镀层。"],
		["flaw", "镀银，内圈露底。"],
		["condition_mended", "实银戒圈变形。"]],
	"item_silver_lock": [
		["sound", "银色里外一致，接合完好。"],
		["flaw", "镀银，锁角露底。"],
		["condition_mended", "锁身补焊。"]],
	"item_tea_cup": [
		["sound", "完好，未见伤损。"],
		["flaw", "断后补接。"],
		["condition_mended", "口沿磕缺。"]]
}

static func build(item: ItemInstance, definition: ItemDefinition) -> Array:
	var result: Array = []
	# Ghost evidence includes operating prohibitions, not just price observations.
	if not definition.ghost_rule_id.is_empty():
		for id in item.revealed_clue_ids:
			result.append(definition.find_clue(id).text)
		return result
	var key := "item_silver_hairpin" if definition.id == "intro_silver_hairpin" else definition.id
	for note in NOTES.get(key, []):
		if note[0] in item.revealed_clue_ids:
			result.append(note[1])
			break
	return result
