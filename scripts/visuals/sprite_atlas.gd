extends RefCounted
## Runtime resource normalization. Source PNGs are never modified.
## Regions and masks use source-image coordinates. A mask is a union of
## Rect2i/Rect2 arrays or PackedVector2Array polygons belonging to one pose.
static func build(path: String, regions: Array = [], frame_size: Vector2i = Vector2i.ZERO, masks: Array = []) -> SpriteFrames:
	# Imported textures survive export even when the original PNG is not packed.
	var image: Image
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			image = texture.get_image()
	if image == null and not path.begins_with("res://"):
		image = Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("SpriteAtlas: cannot read " + path)
		return SpriteFrames.new()
	if image.is_compressed():
		if image.decompress() != OK:
			push_error("SpriteAtlas: cannot decompress " + path)
			return SpriteFrames.new()
	image.convert(Image.FORMAT_RGBA8)
	var source_size := image.get_size()
	var boxes: Array[Rect2i] = []
	if regions.is_empty():
		var columns := 2 if path.get_file().get_basename().ends_with("_atlas") else 4
		var rows := 2 if columns == 2 else 1
		for i in 4:
			var row := floori(float(i) / columns)
			var x0 := floori(float((i % columns) * source_size.x) / columns)
			var x1 := floori(float(((i % columns) + 1) * source_size.x) / columns)
			var y0 := floori(float(row * source_size.y) / rows)
			var y1 := floori(float((row + 1) * source_size.y) / rows)
			boxes.append(Rect2i(x0, y0, x1 - x0, y1 - y0))
	else:
		for region in regions:
			boxes.append(_rect(region).intersection(Rect2i(Vector2i.ZERO, source_size)))
	if boxes.size() != 4:
		push_error("SpriteAtlas: exactly four pose regions required")
		return SpriteFrames.new()
	var poses: Array[Image] = []
	var bounds: Array[Rect2i] = []
	var shared_size := Vector2i.ONE
	for i in 4:
		var box := boxes[i]
		if box.size.x <= 0 or box.size.y <= 0:
			push_error("SpriteAtlas: empty pose region")
			return SpriteFrames.new()
		var pose := image.get_region(box)
		# Generation edge noise is below visual alpha; do not let it move anchors.
		for y in pose.get_height():
			for x in pose.get_width():
				if pose.get_pixel(x, y).a <= 0.015:
					pose.set_pixel(x, y, Color.TRANSPARENT)
		if i < masks.size() and _has_mask(masks[i]):
			for y in pose.get_height():
				for x in pose.get_width():
					if not _inside_mask(Vector2(x + box.position.x + 0.5, y + box.position.y + 0.5), masks[i]):
						pose.set_pixel(x, y, Color.TRANSPARENT)
		var used := pose.get_used_rect()
		poses.append(pose)
		bounds.append(used)
		shared_size.x = maxi(shared_size.x, used.size.x)
		shared_size.y = maxi(shared_size.y, used.size.y)
	# All poses share one scale. Low defeat poses keep their smaller stature.
	var output_size := shared_size if frame_size.x <= 0 or frame_size.y <= 0 else frame_size
	var ratio := minf(float(output_size.x) / shared_size.x, float(output_size.y) / shared_size.y)
	var textures: Array[Texture2D] = []
	for i in 4:
		var canvas := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		if bounds[i].has_area():
			var cut := poses[i].get_region(bounds[i])
			var scaled := Vector2i(maxi(1, roundi(cut.get_width() * ratio)), maxi(1, roundi(cut.get_height() * ratio)))
			if scaled != cut.get_size():
				cut.resize(scaled.x, scaled.y, Image.INTERPOLATE_NEAREST)
			canvas.blit_rect(cut, Rect2i(Vector2i.ZERO, scaled), Vector2i((output_size.x - scaled.x) / 2, output_size.y - scaled.y))
		textures.append(ImageTexture.create_from_image(canvas))
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for name in ["idle", "cast", "attack", "hurt", "defeat"]:
		result.add_animation(name)
		result.set_animation_speed(name, 8.0)
		result.set_animation_loop(name, name == "idle")
	for entry in [{"name":"idle", "poses":[0]}, {"name":"cast", "poses":[0, 1, 0]}, {"name":"attack", "poses":[0, 1, 0]}, {"name":"hurt", "poses":[2, 0]}, {"name":"defeat", "poses":[3]}]:
		for index in entry.poses:
			result.add_frame(entry.name, textures[index])
	return result

static func frames(path: String, regions: Array = [], frame_size: Vector2i = Vector2i.ZERO, masks: Array = []) -> SpriteFrames:
	return build(path, regions, frame_size, masks)

static func _rect(value: Variant) -> Rect2i:
	if value is Rect2i or value is Rect2:
		return Rect2i(value)
	if value is Array and value.size() == 4:
		return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
	return Rect2i()

static func _inside_mask(point: Vector2, mask: Variant) -> bool:
	if mask is PackedVector2Array:
		return Geometry2D.is_point_in_polygon(point, mask)
	if mask is Rect2i or mask is Rect2:
		return Rect2(_rect(mask)).has_point(point)
	if mask is Array:
		if mask.size() == 4 and (mask[0] is int or mask[0] is float):
			return Rect2(_rect(mask)).has_point(point)
		for part in mask:
			if _inside_mask(point, part):
				return true
	return false

static func _has_mask(mask: Variant) -> bool:
	if mask == null:
		return false
	if mask is Array or mask is PackedVector2Array:
		return not mask.is_empty()
	return mask is Rect2i or mask is Rect2
