shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Průhledná mřížka stavitelných polí (zobrazí se při stavění). UV 0..1 uvnitř každé buňky.

uniform vec4 color : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float fill_alpha = 0.10;
uniform float line_alpha = 0.55;

void fragment() {
	vec2 e = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.0, 0.07, min(e.x, e.y));
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(fill_alpha + edge * line_alpha, 0.0, 1.0) * pulse;
}
