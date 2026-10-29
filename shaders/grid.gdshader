shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Průhledná mřížka stavitelných polí (zobrazí se při stavění). UV 0..1 uvnitř každé buňky.
// Vertex COLOR.a = výškový stupeň pole (0 rovina, 0.5 kopec, 1 vrchol): vyvýšená pole mají zlatý nádech a kroužky (1 nebo 2).

uniform vec4 color : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform vec4 high_color : source_color = vec4(1.0, 0.82, 0.35, 1.0);
uniform float fill_alpha = 0.10;
uniform float line_alpha = 0.55;

void fragment() {
	vec2 e = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.0, 0.07, min(e.x, e.y));
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	float tier = COLOR.a;
	float d = length(UV - vec2(0.5));
	float ring1 = (1.0 - smoothstep(0.0, 0.045, abs(d - 0.30))) * step(0.25, tier);
	float ring2 = (1.0 - smoothstep(0.0, 0.045, abs(d - 0.15))) * step(0.75, tier);
	float mark = max(ring1, ring2);
	vec3 base = mix(color.rgb, high_color.rgb, step(0.25, tier));
	ALBEDO = base;
	ALPHA = clamp(fill_alpha + step(0.25, tier) * 0.12 + edge * line_alpha + mark * 0.7, 0.0, 1.0) * pulse;
}
