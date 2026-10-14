extends Button
## Shared illustrated entity-card face. The combat model remains authoritative.
const FONT = preload("res://assets/msyh.ttc")
const COPPER = Color("bc925b")
const TEAL = Color("8ce5e6")
var card_data: Dictionary = {}
var illustration: Texture2D
var equipped = false
var collection_face = false
var hovered = false
var title_label: Label
var state_label: Label
static var texture_cache: Dictionary = {}

func _ready():
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())
	title_label = _label(15, Color("f4e6cc"))
	state_label = _label(11, Color("c4d8db"))
	resized.connect(_layout)
	_layout()
	_refresh()

func _label(font_size: int, color: Color) -> Label:
	var node = Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 3)
	node.add_theme_color_override("font_outline_color", Color("071522"))
	node.clip_text = true
	add_child(node)
	return node

func configure(data: Dictionary, is_collection = false, is_equipped = false):
	card_data = data.duplicate(true)
	collection_face = is_collection
	equipped = is_equipped
	var kind = str(data.get("type", "fire"))
	var path = "res://assets/cards/%s.png" % kind
	if texture_cache.has(kind): illustration = texture_cache[kind]
	elif ResourceLoader.exists(path):
		illustration = load(path)
		texture_cache[kind] = illustration
	tooltip_text = "%s\n%s\n灵能 %d  ·  冷却 %.0f秒\n%s" % [data.get("name", ""), data.get("description", ""), data.get("cost", 0), data.get("cooldown", 0), "实体 " + str(data.get("id", ""))]
	if not str(data.get("reason", "")).is_empty(): tooltip_text += "\n" + str(data.reason)
	_refresh()

func _layout():
	if title_label == null: return
	title_label.add_theme_font_size_override("font_size", 21 if size.x > 300 else 15)
	state_label.add_theme_font_size_override("font_size", 15 if size.x > 300 else 11)
	title_label.position = Vector2(10, size.y - 41)
	title_label.size = Vector2(size.x - 20, 23)
	state_label.position = Vector2(10, size.y - 21)
	state_label.size = Vector2(size.x - 20, 18)

func _refresh():
	if title_label != null:
		title_label.text = str(card_data.get("name", ""))
		var remaining = float(card_data.get("remaining", 0))
		if collection_face:
			state_label.text = "✓ 已装备" if equipped else "点击装备"
		elif card_data.get("selected", false):
			state_label.text = "已选中 · 确认施放"
		elif remaining > 0:
			state_label.text = "冷却 %.1f秒" % remaining
		elif card_data.get("state", "ready") == "energy":
			state_label.text = "费用不足"
		elif card_data.get("state", "ready") == "condition":
			state_label.text = "条件不满足"
		else:
			state_label.text = "可用"
	queue_redraw()

func _draw():
	var chosen = equipped if collection_face else bool(card_data.get("selected", false))
	var edge = TEAL if hovered else (Color("f5c980") if chosen else COPPER)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c192b"))
	var art_rect = Rect2(5, 5, size.x - 10, size.y - 10)
	if illustration != null:
		var tex_size = illustration.get_size()
		var crop_height = tex_size.x * art_rect.size.y / art_rect.size.x
		var crop = Rect2(0, (tex_size.y - crop_height) * 0.5, tex_size.x, crop_height)
		draw_texture_rect_region(illustration, art_rect, crop)
	else:
		# Loading-safe placeholder; approved illustrations replace this automatically.
		draw_rect(art_rect, Color("193044"))
		draw_arc(size * 0.5, 28, 0, TAU, 32, COPPER, 2)
		draw_line(size * 0.5 - Vector2(0, 23), size * 0.5 + Vector2(0, 23), TEAL, 2)
	draw_rect(Rect2(5, size.y - 44, size.x - 10, 39), Color(0.025, 0.06, 0.11, 0.92))
	if disabled: draw_rect(art_rect, Color(0.015, 0.025, 0.045, 0.45))
	draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), edge, false, 2)
	draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color("6b573e"), false, 1)
	for corner in [Vector2(7,7), Vector2(size.x-7,7), Vector2(7,size.y-7), size-Vector2(7,7)]:
		var inward = Vector2(1 if corner.x < size.x/2 else -1, 1 if corner.y < size.y/2 else -1)
		draw_line(corner, corner + Vector2(inward.x * 13, 0), edge, 2)
		draw_line(corner, corner + Vector2(0, inward.y * 13), edge, 2)
		draw_circle(corner + inward * 3, 1.5, edge)
	var badge = Vector2(22, 23)
	draw_circle(badge, 16, Color("0a1c2c"))
	draw_arc(badge, 16, 0, TAU, 32, edge, 1.5)
	draw_string(FONT, badge + Vector2(-5, 6), str(card_data.get("cost", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f5e4bb"))
	var remaining = float(card_data.get("remaining", 0))
	if remaining > 0:
		var center = Vector2(size.x - 25, 24)
		draw_circle(center, 17, Color(0.03,0.07,0.13,0.94))
		draw_arc(center, 15, -PI/2, -PI/2 + TAU * clampf(remaining / maxf(1, float(card_data.get("cooldown",1))), 0, 1), 32, TEAL, 2)
		draw_string(FONT, center + Vector2(-11,5), "%.0f" % ceilf(remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d3f5f4"))
	elif chosen:
		draw_circle(Vector2(size.x-22,23), 12, Color("123c43"))
		draw_string(FONT, Vector2(size.x-30,29), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TEAL)
