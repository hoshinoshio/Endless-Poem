extends Control
signal card_clicked(card_id: String)
## Replace FONT here when the calligraphy font is ready.
const FONT = preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
const FRAME = preload("res://assets/cards/frame_c/card_frame_c.svg")
const Palette = preload("res://scripts/authority/authority_palette.gd")
const DESIGN_SIZE = Vector2(250, 350)
const ART_WINDOW = Rect2(24, 62, 202, 168)
const ART_MASK = preload("res://scripts/authority/card_art_mask.gdshader")

@export var card_scale: float = 0.6:
	set(value):
		card_scale = maxf(value, 0.01)
		_update_scale()
var card: Dictionary = {}
var selected: bool = false
var design: Control
var art_clip: Control
var illustration: TextureRect
var placeholder_clock: Control
var gem: TextureRect
var title_label: Label
var description_label: Label

class PlaceholderClock extends Control:
	func _draw() -> void:
		var center := Vector2(101, 68)
		var ink := Color("e9eefa")
		var gold := Color("e7b75c")
		var random := RandomNumberGenerator.new()
		random.seed = 7
		for index in range(46):
			var point := Vector2(random.randf_range(10, 192), random.randf_range(8, 158))
			draw_circle(point, random.randf_range(0.3, 1.1), Color(0.87, 0.90, 1.0, 0.65))
		draw_circle(center, 44, Color(0.07, 0.10, 0.22, 0.55))
		draw_arc(center, 47, 0, TAU, 96, gold, 1.0, true)
		draw_arc(center, 44, 0, TAU, 96, ink, 1.6, true)
		for index in range(12):
			var direction := Vector2.from_angle(index * TAU / 12.0 - PI / 2.0)
			draw_line(center + direction * (36 if index % 3 == 0 else 40), center + direction * 44, ink, 1.2, true)
		draw_line(center, center + Vector2(-22, -17), ink, 3, true)
		draw_line(center, center + Vector2(26, -26), ink, 2, true)
		draw_circle(center, 3.4, gold)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	design = Control.new()
	design.name = "Design"
	design.size = DESIGN_SIZE
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(design)
	art_clip = Control.new()
	art_clip.name = "ArtClip"
	art_clip.position = ART_WINDOW.position
	art_clip.size = ART_WINDOW.size
	art_clip.clip_contents = true
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(art_clip)
	illustration = _texture_rect("Illustration", Rect2(Vector2.ZERO, ART_WINDOW.size), art_clip)
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mask := ShaderMaterial.new()
	mask.shader = ART_MASK
	illustration.material = mask
	placeholder_clock = PlaceholderClock.new()
	placeholder_clock.name = "PlaceholderClock"
	placeholder_clock.size = ART_WINDOW.size
	placeholder_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_clip.add_child(placeholder_clock)
	var frame := _texture_rect("Frame", Rect2(Vector2.ZERO, DESIGN_SIZE), design)
	frame.texture = FRAME
	gem = _texture_rect("Gem", Rect2(189, 6, 52, 52), design)
	title_label = _label("Name", Rect2(0, 14, 236, 34), 21, Color("f0dba8"))
	var title_font := FontVariation.new()
	title_font.base_font = FONT
	title_font.spacing_glyph = 5
	title_label.add_theme_font_override("font", title_font)
	# Inset the text within the 22..228 frame so short effects wrap into readable lines.
	description_label = _label("Description", Rect2(50, 244, 150, 80), 14, Color("e8e3d6"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_scale()
	configure({})

func _texture_rect(node_name: String, rect: Rect2, parent: Control) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _label(node_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(label)
	return label

func _update_scale() -> void:
	custom_minimum_size = DESIGN_SIZE * card_scale
	size = custom_minimum_size
	if is_instance_valid(design): design.scale = Vector2.ONE * card_scale
	queue_redraw()

func configure(value: Dictionary) -> void:
	card = value.duplicate(true)
	title_label.text = str(card.get("title", ""))
	description_label.text = str(card.get("description", ""))
	tooltip_text = description_label.text
	var path := Palette.gem_path(str(card.get("authority", "time")))
	gem.texture = load(path) if not path.is_empty() else null
	var art_path := str(card.get("art", ""))
	var art: Texture2D = load(art_path) as Texture2D if not art_path.is_empty() and ResourceLoader.exists(art_path) else null
	placeholder_clock.visible = art == null
	if art == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("26346a"), Color("0a0f22")])
		var sky := GradientTexture2D.new()
		sky.gradient = gradient
		sky.width = 202
		sky.height = 168
		sky.fill_from = Vector2(0.5, 0)
		sky.fill_to = Vector2(0.5, 1)
		art = sky
	illustration.texture = art

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(str(card.get("id", "")))
		accept_event()

func _draw() -> void:
	if not selected: return
	# A two-screen-pixel outline outside the frame, independent of card scale.
	var w := DESIGN_SIZE.x * card_scale
	var h := DESIGN_SIZE.y * card_scale
	var cut := 13 * card_scale
	var outline := PackedVector2Array([
		Vector2(cut, -2), Vector2(w - cut, -2), Vector2(w + 2, cut),
		Vector2(w + 2, h - cut), Vector2(w - cut, h + 2), Vector2(cut, h + 2),
		Vector2(-2, h - cut), Vector2(-2, cut), Vector2(cut, -2)])
	draw_polyline(outline, Color("8fd4f1"), 2.0, true)
