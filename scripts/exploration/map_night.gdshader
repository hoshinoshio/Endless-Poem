shader_type canvas_item;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float lightness = dot(source.rgb, vec3(0.2126,0.7152,0.0722));
	vec3 night = vec3(0.22,0.28,0.54)*lightness + vec3(0.022,0.018,0.065);
	// Keep authored texture details while the frozen dusk gives way to the first night.
	night += source.rgb*vec3(0.035,0.035,0.055);
	COLOR *= vec4(mix(source.rgb,night,night_amount),source.a);
}
