shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Průhledná mřížka stavitelných polí (zobrazí se při stavění nebo klávesou G). UV 0..1 uvnitř každé buňky.
// Každé pole má světlou čáru po obvodu a pod ní tmavý měkký lem, aby byla mřížka čitelná na sněhu i na písku.
// Vertex COLOR.a = výškový stupeň pole (0 rovina, 0.5 kopec, 1 vrchol): vyvýšená pole mají zlatý nádech a kroužky (1 nebo 2).

uniform vec4 color : source_color = vec4(0.84, 0.97, 1.0, 1.0);
uniform vec4 high_color : source_color = vec4(1.0, 0.84, 0.30, 1.0);
uniform vec4 dark_color : source_color = vec4(0.02, 0.06, 0.12, 1.0);
uniform float fill_alpha = 0.15;
uniform float line_alpha = 0.95;
uniform float shade_alpha = 0.38;

void fragment() {
	vec2 e = min(UV, vec2(1.0) - UV);
	float m = min(e.x, e.y);
	float pulse = 0.92 + 0.08 * sin(TIME * 3.0);
	float tier = COLOR.a;
	float hi = step(0.25, tier);
	float d = length(UV - vec2(0.5));
	float ring1 = (1.0 - smoothstep(0.0, 0.05, abs(d - 0.30))) * step(0.25, tier);
	float ring2 = (1.0 - smoothstep(0.0, 0.05, abs(d - 0.15))) * step(0.75, tier);
	float mark = max(ring1, ring2);
	float line = 1.0 - smoothstep(0.075, 0.115, m);
	float shade = (1.0 - smoothstep(0.115, 0.22, m)) * (1.0 - line);
	vec3 base = mix(color.rgb, high_color.rgb, hi);
	float a_bright = max(line * line_alpha, mark * 0.85);
	float a_fill = fill_alpha + hi * 0.12;
	float a_shade = shade * shade_alpha;
	float a_in = max(a_fill, a_shade);
	vec3 rgb_in = mix(base, dark_color.rgb, a_shade / max(a_shade + a_fill, 0.0001));
	ALBEDO = mix(rgb_in, base, a_bright / max(a_bright + a_in, 0.0001));
	ALPHA = clamp(a_bright + a_in * (1.0 - a_bright), 0.0, 1.0) * pulse;
}
