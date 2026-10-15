shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	float vignette = smoothstep(0.22, 0.75, length(UV - vec2(0.5)));
	COLOR = vec4(mix(c, vec3(gray), 0.7) * (0.88 - vignette * 0.44), 1.0);
}
