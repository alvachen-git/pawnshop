class_name CustomerReplyModel
extends RefCounted

const LINES := {
	"satisfied": "掌柜爽快，就照这个价。",
	"reluctant": "唉，再低也舍不得了……就这么着吧。",
	"refused": "这价钱谈不拢，东西我带走了。",
	"timed_out": "时候不早了，我还有事，先走一步。",
	"rejected": "既然掌柜不收，我再去别家问问。",
}

static func build(receipt: Dictionary, operation: Dictionary) -> Dictionary:
	var style := String(receipt.get("reply_style", ""))
	var name := String(receipt.get("reply_name", ""))
	if receipt.kind in ["acquisition", "pawn_loan"]:
		var counter: Dictionary = operation.get("before", {}).get("counter", {})
		var visual: Dictionary = counter.get("visual", {})
		name = String(visual.get("customer_name", "客人"))
		# Compare with the public request before this quote, never a hidden reserve.
		var asking := int(counter.get("trade", {}).get("pawn_asking", 0)) if receipt.kind == "pawn_loan" else int(visual.get("asking", 0))
		style = "reluctant" if -int(receipt.amount) < asking or visual.get("attitude", "") == "显得不耐烦" else "satisfied"
	var line := String(LINES.get(style, ""))
	if style == "timed_out" and receipt.get("quote_refused", false): line = "这个价钱不成。" + line
	return {"style": style, "text": "%s：“%s”" % [name, line] if not line.is_empty() else ""}
