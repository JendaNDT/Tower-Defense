shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// Vodopád padající z okraje ostrova do oblaků. UV.x = 0..1 napříč, UV.y = vzdálenost pod hranou (m).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 water_color : source_color = vec4(0.22, 0.55, 0.88, 1.0);
uniform float fall_len = 30.0;

void vertex() {
	VERTEX.x += sin(TIME * 2.6 + VERTEX.y * 0.55) * 0.06;
	VERTEX.z += cos(TIME * 2.1 + VERTEX.y * 0.4) * 0.05;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float n1 = texture(noise_tex, vec2(x * 1.6, y * 0.05 - TIME * 0.55)).r;
	float n2 = texture(noise_tex, vec2(x * 4.5 + 0.3, y * 0.08 - TIME * 0.95)).r;
	float streaks = smoothstep(0.35, 0.8, n1 * 0.55 + n2 * 0.6);
	float side = smoothstep(0.0, 0.14, x) * smoothstep(1.0, 0.86, x);
	float fade = 1.0 - smoothstep(fall_len * 0.5, fall_len, y);
	float lip = 1.0 - smoothstep(0.0, 3.0, y);
	float edge = 1.0 - smoothstep(0.0, 0.1, min(x, 1.0 - x));
	vec3 col = mix(water_color.rgb, vec3(1.0), clamp(streaks * 0.8 + lip * 0.6 + edge * 0.7, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * 0.18;
	ROUGHNESS = 0.3;
	ALPHA = clamp(0.72 + streaks * 0.28, 0.0, 1.0) * side * fade;
}
