shader_type canvas_item;
varying vec2 art_position;

void vertex() {
	art_position = VERTEX;
}

void fragment() {
	// Local position keeps the radius stable even when COVERED crops texture UVs.
	vec2 q = abs(art_position - vec2(101.0, 84.0)) - vec2(93.0, 76.0);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 8.0;
	float feather = max(fwidth(distance_to_edge), 0.001);
	COLOR.a *= 1.0 - smoothstep(-feather, 0.0, distance_to_edge);
}
