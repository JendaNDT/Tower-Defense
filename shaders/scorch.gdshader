shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Spálená skvrna po výbuchu přilepená na terén (mizí). UV = rovinné souřadnice disku 0..1.

uniform float alpha = 0.5;
uniform float seed = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float ragged = 0.80 + 0.2 * sin(a * 5.0 + seed) * sin(a * 3.0 - seed * 1.7) + 0.06 * sin(a * 11.0 + seed * 3.0);
	float m = 1.0 - smoothstep(0.3, ragged, d);
	float core = 1.0 - smoothstep(0.0, 0.55, d);
	ALBEDO = mix(vec3(0.07, 0.055, 0.045), vec3(0.015), core);
	ALPHA = m * alpha;
}
