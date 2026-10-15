extends Control
## Standalone art review; deliberately not referenced by the main flow.
const Card = preload("res://scripts/authority/time_card.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
const Palette = preload("res://scripts/authority/authority_palette.gd")

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0d1222")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_heading("卡面 C · 钟表机芯", Vector2(70, 28), 27)
	_heading("三张时间权柄 · 收藏尺寸 0.9（中间选中）", Vector2(70, 72), 16)
	var catalog := Temporal.card_catalog()
	for index in catalog.size():
		var face := Card.new()
		face.name = "TimeCard%d" % index
		face.card_scale = 0.9
		face.position = Vector2(292.5 + index * 315, 108)
		face.configure(catalog[index])
		face.set_selected(index == 1)
		add_child(face)
	_heading("七种权柄 · 探索尺寸 0.6 · 时间 = 群青，空间 = 琥珀", Vector2(70, 478), 19)
	var index := 0
	for id in Palette.AUTHORITIES:
		var face := Card.new()
		face.name = "GemCard_" + id
		face.position = Vector2(123 + index * 174, 536)
		face.configure({"id": id, "authority": id, "title": Palette.display_name(id) + " · 示例", "description": "权柄宝石与卡面布局示例。"})
		add_child(face)
		index += 1
	if "--capture-preview" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _heading(text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", Card.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0dba8"))
	add_child(label)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Preview capture requires a rendering display server")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs"))
	var error := get_viewport().get_texture().get_image().save_png("res://logs/card_frame_preview.png")
	print("CARD_FRAME_PREVIEW_CAPTURE=", error_string(error))
	get_tree().quit(0 if error == OK else 1)
