extends RefCounted
## Four authored idle poses normalized into the existing action canvas.
## Source PNGs and original SpriteFrames remain untouched.
static func apply(frames: SpriteFrames, path: String, regions: Array = []) -> SpriteFrames:
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") == 0:
		push_error("IdleMotionAssets: original idle reference required")
		return frames
	var reference := frames.get_frame_texture(&"idle", 0).get_image()
	var image: Image
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			image = texture.get_image()
	if image == null:
		image = Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("IdleMotionAssets: cannot read " + path)
		return frames
	for source_image in [reference, image]:
		if source_image.is_compressed() and source_image.decompress() != OK:
			push_error("IdleMotionAssets: cannot decompress image")
			return frames
		source_image.convert(Image.FORMAT_RGBA8)
	var boxes: Array[Rect2i] = []
	if regions.is_empty():
		for i in 4:
			var x0 := floori(float(i % 2) * image.get_width() / 2.0)
			var x1 := floori(float(i % 2 + 1) * image.get_width() / 2.0)
			var y0 := floori(float(i / 2) * image.get_height() / 2.0)
			var y1 := floori(float(i / 2 + 1) * image.get_height() / 2.0)
			boxes.append(Rect2i(x0,y0,x1-x0,y1-y0))
	else:
		for entry in regions:
			var box := Rect2i(entry) if entry is Rect2 or entry is Rect2i else Rect2i(int(entry[0]),int(entry[1]),int(entry[2]),int(entry[3]))
			boxes.append(box.intersection(Rect2i(Vector2i.ZERO,image.get_size())))
	if boxes.size() != 4:
		push_error("IdleMotionAssets: exactly four regions required")
		return frames
	var poses: Array[Image] = []
	var bounds: Array[Rect2i] = []
	for box in boxes:
		if not box.has_area():
			push_error("IdleMotionAssets: empty region")
			return frames
		var pose := image.get_region(box)
		for y in pose.get_height():
			for x in pose.get_width():
				if pose.get_pixel(x,y).a <= 0.015:
					pose.set_pixel(x,y,Color.TRANSPARENT)
		var used := pose.get_used_rect()
		if not used.has_area():
			push_error("IdleMotionAssets: empty authored pose")
			return frames
		poses.append(pose)
		bounds.append(used)
	var original_bounds := reference.get_used_rect()
	if not original_bounds.has_area():
		original_bounds = Rect2i(Vector2i.ZERO,reference.get_size())
	# One ratio for the entire sequence. Other poses keep their authored differences.
	var ratio := float(original_bounds.size.y) / bounds[0].size.y
	var output := frames.duplicate(false) as SpriteFrames
	# Wider authored idle poses receive transparent padding on every animation.
	# This preserves all original pixels, height and shared action/idle fit.
	var foot := Vector2i(original_bounds.position.x + original_bounds.size.x / 2, original_bounds.end.y)
	var horizontal_padding := 0
	for bound in bounds:
		var width := maxi(1,roundi(bound.size.x * ratio))
		horizontal_padding = maxi(horizontal_padding,maxi(width / 2 - foot.x,foot.x + width - width / 2 - reference.get_width()))
	if horizontal_padding > 0:
		for state in output.get_animation_names():
			for index in output.get_frame_count(state):
				var original_texture := output.get_frame_texture(state,index)
				var original_image := original_texture.get_image()
				if original_image.is_compressed():
					original_image.decompress()
				var padded := Image.create(reference.get_width()+horizontal_padding*2,reference.get_height(),false,Image.FORMAT_RGBA8)
				padded.fill(Color.TRANSPARENT)
				padded.blit_rect(original_image,Rect2i(Vector2i.ZERO,original_image.get_size()),Vector2i(horizontal_padding,0))
				output.set_frame(state,index,ImageTexture.create_from_image(padded),output.get_frame_duration(state,index))
	foot.x += horizontal_padding
	output.clear(&"idle")
	output.set_animation_speed(&"idle",4.0)
	output.set_animation_loop(&"idle",true)
	for i in 4:
		var cut := poses[i].get_region(bounds[i])
		var scaled := Vector2i(maxi(1,roundi(cut.get_width()*ratio)),maxi(1,roundi(cut.get_height()*ratio)))
		cut.resize(scaled.x,scaled.y,Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(reference.get_width()+horizontal_padding*2,reference.get_height(),false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var origin := Vector2i(foot.x-scaled.x/2,foot.y-scaled.y)
		if origin.x < 0 or origin.y < 0 or origin.x+scaled.x > canvas.get_width():
			push_warning("IdleMotionAssets: pose exceeds original action canvas: " + path + " frame " + str(i) + " scaled=" + str(scaled) + " origin=" + str(origin) + " canvas=" + str(canvas.get_size()))
		canvas.blit_rect(cut,Rect2i(Vector2i.ZERO,scaled),origin)
		output.add_frame(&"idle",ImageTexture.create_from_image(canvas))
	return output
