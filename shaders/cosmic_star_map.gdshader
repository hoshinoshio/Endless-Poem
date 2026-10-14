shader_type canvas_item;
render_mode unshaded;
uniform float elapsed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float result = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		result += weight * noise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(3.7, 9.2);
		weight *= 0.5;
	}
	return result;
}
void fragment() {
	vec2 p = UV * vec2(1.6, 1.0);
	p += vec2(elapsed * 0.00025, elapsed * 0.00008);
	float field = fbm(p * 5.0);
	float wisps = fbm(p * 11.0 + vec2(field * 2.0));
	float band = exp(-pow((UV.y - 0.40 - 0.14 * sin(UV.x * 5.0 + field * 2.0)) * 4.0, 2.0));
	float face_quiet = 1.0 - 0.40 * exp(-dot((UV - vec2(0.78, 0.45)) * vec2(4.0, 3.0), (UV - vec2(0.78, 0.45)) * vec2(4.0, 3.0)));
	float title_quiet = mix(0.65, 1.0, smoothstep(0.1, 0.52, UV.x));
	float mist = smoothstep(0.22, 0.78, field) * band * face_quiet * title_quiet;
	vec3 blue = vec3(0.028, 0.085, 0.125) * mist;
	vec3 violet = vec3(0.068, 0.025, 0.095) * wisps * band * face_quiet;
	float lane = smoothstep(0.48, 0.67, fbm(p * 8.0 + vec2(7.0, 2.0)));
	vec3 color = vec3(0.013, 0.022, 0.044) + blue + violet;
	color *= 1.0 - lane * band * 0.35;
	COLOR = vec4(color, 1.0);
}
