shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;
// Energetický vodopád padající z okraje stanice do hlubin. UV.x = 0..1 napříč, UV.y = vzdálenost pod hranou (m).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 core_color : source_color = vec4(0.10, 0.85, 1.00, 1.0);
uniform vec4 accent_color : source_color = vec4(1.00, 0.25, 0.85, 1.0);
uniform float fall_len = 30.0;

void vertex() {
	VERTEX.x += sin(TIME * 2.6 + VERTEX.y * 0.55) * 0.04;
	VERTEX.z += cos(TIME * 2.1 + VERTEX.y * 0.4) * 0.03;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float n1 = texture(noise_tex, vec2(x * 1.6, y * 0.05 - TIME * 0.65)).r;
	float n2 = texture(noise_tex, vec2(x * 4.5 + 0.3, y * 0.08 - TIME * 1.1)).r;
	float streaks = smoothstep(0.35, 0.8, n1 * 0.55 + n2 * 0.6);
	float side = smoothstep(0.0, 0.14, x) * (1.0 - smoothstep(0.86, 1.0, x));
	float fade = 1.0 - smoothstep(fall_len * 0.45, fall_len, y);
	float lip = 1.0 - smoothstep(0.0, 3.0, y);
	float edge = 1.0 - smoothstep(0.0, 0.1, min(x, 1.0 - x));
	float packets = smoothstep(0.85, 1.0, 0.5 + 0.5 * sin(y * 0.8 + TIME * 6.0 + n1 * 6.0));
	vec3 col = mix(core_color.rgb * 0.55, core_color.rgb * 1.4, streaks);
	col += vec3(1.0) * (lip * 0.5 + edge * 0.6);
	col += accent_color.rgb * packets * 0.9 * streaks;
	ALBEDO = col * 1.15;
	ALPHA = clamp(0.6 + streaks * 0.4, 0.0, 1.0) * side * fade;
}
