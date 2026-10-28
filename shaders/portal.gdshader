shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Vířivý portál, ze kterého vycházejí nepřátelé.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 color_a : source_color = vec4(0.35, 0.10, 0.70, 1.0);
uniform vec4 color_b : source_color = vec4(0.20, 0.80, 1.00, 1.0);
uniform float intensity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = a / 6.2831853 + r * 1.4 - TIME * 0.30;
	float n = texture(noise_tex, vec2(swirl, r * 0.7 - TIME * 0.18)).r;
	float n2 = texture(noise_tex, vec2(swirl * 2.0 + 0.4, r * 1.3 + TIME * 0.12)).r;
	float m = clamp(n * 0.7 + n2 * 0.5, 0.0, 1.0);
	vec3 col = mix(color_a.rgb, color_b.rgb, m);
	col += vec3(1.0, 0.85, 1.0) * smoothstep(0.7, 0.95, m) * 0.9;
	col += color_b.rgb * smoothstep(0.78, 0.98, r) * 0.9;
	float disc = 1.0 - smoothstep(0.93, 1.0, r);
	ALBEDO = col * (1.2 * intensity);
	ALPHA = disc * clamp(0.45 + m * 0.55 + smoothstep(0.7, 1.0, r) * 0.4, 0.0, 1.0);
}
