extends Control
signal action_requested(action: String)
const MenuEnvironment = preload("res://scripts/ui/menu_environment.gd")
const CelestialButton = preload("res://scripts/ui/menu_a_button.gd")
var buttons: Dictionary = {}
var background: Control
var portrait_texture: TextureRect
var title_texture: TextureRect
var theme_mode = "A"
var _canvas: Control
var _title_fallback: Label
var _entry_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.size = Vector2(1440, 900)
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	background = MenuEnvironment.new()
	background.name = "ArchitecturalBackground"
	_canvas.add_child(background)
	portrait_texture = _texture(_asset("menu_a_reference_portrait.png", "moonli_prayer_v1.png"), Rect2(378, -23, 1235, 926))
	title_texture = _texture(_asset("menu_a_reference_title.png", "title_logo_silver.png"), Rect2(55, 100, 535, 255))
	var font: Font
	var serif_names := PackedStringArray(["SimSun", "Songti SC", "Source Han Serif SC", "Noto Serif CJK SC"])
	var system_fonts := OS.get_system_fonts()
	var has_serif := false
	for family in serif_names:
		if family in system_fonts:
			has_serif = true
			break
	if has_serif:
		var serif := SystemFont.new()
		serif.font_names = serif_names
		if ResourceLoader.exists("res://assets/fonts/SourceHanSansSC-Regular.otf"):
			serif.fallbacks = [load("res://assets/fonts/SourceHanSansSC-Regular.otf")]
		font = serif
	elif ResourceLoader.exists("res://assets/fonts/SourceHanSansSC-Regular.otf"):
		font = load("res://assets/fonts/SourceHanSansSC-Regular.otf")
	else:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["Microsoft YaHei", "sans-serif"])
		font = fallback
	_title_fallback = Label.new()
	_title_fallback.text = "未尽之诗"
	_title_fallback.position = Vector2(80, 147)
	_title_fallback.add_theme_font_override("font", font)
	_title_fallback.add_theme_font_size_override("font_size", 76)
	_title_fallback.add_theme_color_override("font_color", Color("e5edf6"))
	_title_fallback.visible = title_texture.texture == null
	_canvas.add_child(_title_fallback)
	var names = ["新的探索", "继续探索", "显现权柄", "探索手札", "退出游戏"]
	var keys = ["new", "continue", "authority", "journal", "quit"]
	for i in range(keys.size()):
		var key: String = keys[i]
		var control = CelestialButton.new()
		control.name = key.capitalize() + "Button"
		control.featured = key == "new"
		control.text = names[i]
		control.position = Vector2(58, 395 + i * 89)
		control.size = Vector2(330, 67)
		control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_font_override("font", font)
		control.add_theme_font_size_override("font_size", 32)
		control.add_theme_color_override("font_color", Color("d0dcef"))
		control.add_theme_color_override("font_hover_color", Color("ffffff"))
		control.add_theme_color_override("font_focus_color", Color("ffffff"))
		control.add_theme_color_override("font_pressed_color", Color("bddbff"))
		control.add_theme_color_override("font_disabled_color", Color("66758b"))
		control.pressed.connect(func(): action_requested.emit(key))
		buttons[key] = control
		_canvas.add_child(control)
	resized.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	_entry_elapsed = minf(_entry_elapsed + delta, 0.5)
	_canvas.modulate.a = lerpf(0.8, 1.0, smoothstep(0.0, 0.5, _entry_elapsed))

func _asset(preferred: String, fallback: String) -> String:
	var path := "res://assets/menu/" + preferred
	return path if ResourceLoader.exists(path) else "res://assets/menu/" + fallback

func _texture(path: String, rect: Rect2) -> TextureRect:
	var node = TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path): node.texture = load(path)
	_canvas.add_child(node)
	return node

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var factor = minf(size.x / 1440.0, size.y / 900.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1440, 900) * factor) * 0.5

func set_continue_available(available: bool) -> void:
	buttons["continue"].disabled = not available
	buttons["continue"].tooltip_text = "继续已保存的探索。战斗中退出时，从遭遇前的检查点恢复。" if available else "尚无正在进行的探索。请选择新的探索。"

func presentation_state() -> Dictionary:
	return {"theme": theme_mode, "portrait_fixed": true, "logical_size": Vector2(1440, 900), "canvas_scale": _canvas.scale, "portrait_rect": portrait_texture.get_global_rect(), "background": background.presentation_state()}


