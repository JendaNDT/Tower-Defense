shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Okruh dosahu věže přilepený na terén. UV.x = normalizovaný poloměr (0 střed .. 1 okraj).

uniform vec4 color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float fill_alpha = 0.12;
uniform float ring_alpha = 0.85;
uniform float ring_w = 0.05;

void fragment() {
	float r = UV.x;
	float ring = smoothstep(1.0 - ring_w, 1.0 - ring_w * 0.3, r);
	ALBEDO = color.rgb;
	ALPHA = clamp(fill_alpha + ring * ring_alpha, 0.0, 1.0) * color.a;
}
