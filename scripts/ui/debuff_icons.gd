extends Control
## Read-only snapshot decoration. All drawing and hover feedback pass target input.
var icon_size := 24
var entries: Array = []
var hovered := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func sync_state(enemy: Dictionary, pending: Array) -> void:
	entries.clear()
	if int(enemy.get("hp", 0)) > 0:
		if int(enemy.get("burn", 0)) > 0:
			entries.append({"kind": "burn", "value": str(enemy.burn), "help": "灼烧 %d层：目标行动前每层造成2伤害并清除。" % enemy.burn})
		for effect in pending:
			if effect.get("kind", "") == "delay" and str(effect.get("target", "")) == str(enemy.id):
				entries.append({"kind": "delay", "value": "%.1f" % float(effect.remaining), "help": "延时爆发：%.1f战斗秒后结算。" % float(effect.remaining)})
	size = Vector2(entries.size() * (icon_size + 38), icon_size)
	visible = not entries.is_empty()
	queue_redraw()

func _process(_delta: float) -> void:
	var next := -1
	var local := get_local_mouse_position()
	for i in entries.size():
		if Rect2(i * (icon_size + 38), 0, icon_size + 34, icon_size).has_point(local): next = i
	if next != hovered:
		hovered = next
		queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	for i in entries.size():
		var origin := Vector2(i * (icon_size + 38), 0)
		var cell := float(icon_size) / 12.0
		draw_rect(Rect2(origin, Vector2.ONE * icon_size), Color("14212c"))
		draw_rect(Rect2(origin, Vector2.ONE * icon_size), Color("b99059"), false, 1)
		if entries[i].kind == "burn":
			# Integer-grid stepped flame; native Canvas drawing keeps edges crisp.
			for row in [[5,1,2,3],[4,3,4,2],[3,5,6,2],[2,7,8,3],[3,10,6,1]]:
				draw_rect(Rect2(origin + Vector2(row[0],row[1]) * cell, Vector2(row[2],row[3]) * cell), Color("f48438"))
			draw_rect(Rect2(origin + Vector2(5,7)*cell, Vector2(3,3)*cell), Color("ffe5a0"))
		else:
			for row in [[3,1,6,1],[3,10,6,1],[3,2,1,2],[8,2,1,2],[4,4,1,1],[7,4,1,1],[5,5,2,2],[4,7,4,1],[3,8,6,2]]:
				draw_rect(Rect2(origin + Vector2(row[0],row[1])*cell, Vector2(row[2],row[3])*cell), Color("91dcf1"))
		draw_string(font, origin + Vector2(icon_size + 4, icon_size - 5), entries[i].value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff1d8"))
	if hovered >= 0 and hovered < entries.size():
		var text := str(entries[hovered].help)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		var box := Rect2(0, icon_size + 5, width, 30)
		draw_rect(box, Color("101922"))
		draw_rect(box, Color("b99059"), false, 1)
		draw_string(font, box.position + Vector2(10,21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff1d8"))
