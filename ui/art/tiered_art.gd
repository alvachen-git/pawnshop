class_name TieredArt
extends RefCounted

# Runtime atlas regions; the generated source image is never modified.
static func cell(path: String, column: int, row: int) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null: return null
	var result := AtlasTexture.new()
	result.atlas = source
	var size := source.get_size()/Vector2(4,3)
	result.region = Rect2(Vector2(column,row)*size+Vector2(2,2),size-Vector2(4,4))
	if path.ends_with("/repeater.png"):
		var edges := [0.0,418.0/1254.0,784.0/1254.0,1.0]
		result.region.position.y = edges[row]*source.get_height()+2
		result.region.size.y = (edges[row+1]-edges[row])*source.get_height()-4
	return result

static func plate(state: RunState, item: ItemInstance, tier: int, reference := false) -> Texture2D:
	if TieredAppraisal.stage(state,item.instance_id,tier).is_empty(): return null
	var path: String = TieredAppraisal.config(state,item).atlas
	if reference: return cell(path,3 if tier == 2 else 0,0 if tier == 2 else 2)
	var variant := ["sound","mended","flawed"].find(item.selected_variant_id)
	if tier == 2 and item.goods.precision.hidden: variant = 3
	return cell(path,variant,1 if tier == 2 else 2)
