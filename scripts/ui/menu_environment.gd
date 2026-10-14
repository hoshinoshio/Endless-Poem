extends Control
## Approved A observatory on the fixed 1440 × 900 logical canvas.
const BACKGROUND_PATH = "res://assets/menu/menu_a_reference_background.png"
const FALLBACK_PATH = "res://assets/menu/night_terrace.png"
const SkyGlints = preload("res://scripts/ui/menu_a_sky.gd")
var _elapsed := 0.0
var _terrace: TextureRect
var _sky
var _loaded_path := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1440, 900)
	var base = ColorRect.new()
	base.color = Color("080f20")
	base.size = size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_terrace = TextureRect.new()
	_terrace.name = "NightTerrace"
	_terrace.size = size
	_terrace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrace.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_terrace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loaded_path = BACKGROUND_PATH if ResourceLoader.exists(BACKGROUND_PATH) else FALLBACK_PATH
	if ResourceLoader.exists(_loaded_path): _terrace.texture = load(_loaded_path)
	add_child(_terrace)
	_sky = SkyGlints.new()
	_sky.size = size
	add_child(_sky)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if delta <= 0.0: return
	_elapsed += delta
	if is_instance_valid(_sky):
		_sky.elapsed = _elapsed
		_sky.queue_redraw()

func presentation_state() -> Dictionary:
	return {"environment": "night_terrace", "art_direction": "A_gothic_observatory", "background_path": _loaded_path, "background_loaded": is_instance_valid(_terrace) and _terrace.texture != null, "elapsed": _elapsed, "floor_motion": Vector2.ZERO, "anomalies": [], "constellation_lines": [], "star_count": _sky.stars.size() if is_instance_valid(_sky) else 0}

