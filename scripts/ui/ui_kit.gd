extends RefCounted
## Shared builders for the menu-side pages (collection, journal, help).

const PAPER = Color("f0e4cf")
const MUTED = Color("a7bdc7")
const GOLD = Color("c9a16b")
const INK = Color("122132")
const PANEL_INK = Color("111d31")
const COPPER = Color("b88b55")

static func style(bg: Color, border: Color, radius = 8) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func panel(rect: Rect2, parent: Control, bg = Color("122033")) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(bg, COPPER, 4))
	parent.add_child(p)
	return p

static func label_text(text_value: String, rect: Rect2, parent: Control, font_size = 20, color = PAPER) -> Label:
	var l = Label.new()
	l.text = text_value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func button(text_value: String, rect: Rect2, callback: Callable, parent: Control, primary = false) -> Button:
	var b = Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.add_theme_color_override("font_color", INK if primary else PAPER)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", style(GOLD if primary else Color("172b3b"), GOLD if primary else Color("7f694b")))
	b.add_theme_stylebox_override("hover", style(Color("ecd09c") if primary else Color("274557"), GOLD))
	b.add_theme_stylebox_override("pressed", style(Color("af8555") if primary else Color("102231"), PAPER))
	b.add_theme_stylebox_override("disabled", style(Color("122033"), Color("274557")))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
