class_name ShopStatusView
extends PanelContainer

func render_status(text: String) -> void:
	$StatusMargin/StatusColumn/StaticStatus.text = text


func show_content_ready(item_count: int, customer_count: int) -> void:
	%ContentStatus.text = "内容校验通过 · 物品 %d / 顾客 %d" % [item_count, customer_count]
	%ContentStatus.modulate = Color("8fc7a2")


func show_content_error(message: String) -> void:
	%ContentStatus.text = "内容加载失败 · %s" % message
	%ContentStatus.modulate = Color("d98b82")
