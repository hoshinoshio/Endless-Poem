extends RefCounted
## Gem colors belong to the supplied artwork, never to card UI code.
const AUTHORITIES = {
	"magic": {"name": "魔法", "gem": "res://assets/cards/frame_c/gem_magic.svg"},
	"time": {"name": "时间", "gem": "res://assets/cards/frame_c/gem_time.svg"},
	"space": {"name": "空间", "gem": "res://assets/cards/frame_c/gem_space.svg"},
	"ether": {"name": "以太", "gem": "res://assets/cards/frame_c/gem_ether.svg"},
	"life": {"name": "生命", "gem": "res://assets/cards/frame_c/gem_life.svg"},
	"self": {"name": "真我", "gem": "res://assets/cards/frame_c/gem_self.svg"},
	"end": {"name": "终末", "gem": "res://assets/cards/frame_c/gem_end.svg"},
}

static func display_name(id: String) -> String:
	return str(AUTHORITIES.get(id, {}).get("name", ""))

static func gem_path(id: String) -> String:
	return str(AUTHORITIES.get(id, {}).get("gem", ""))
