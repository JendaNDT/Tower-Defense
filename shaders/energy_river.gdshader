shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;
// Energetická řeka (sci-fi): UV.x = vzdálenost po toku (m), UV.y = -1..1 napříč. Světelné pruhy plynou po proudu.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 deep_color : source_color = vec4(0.01, 0.08, 0.22, 1.0);
uniform vec4 core_color : source_color = vec4(0.10, 0.85, 1.00, 1.0);
uniform vec4 accent_color : source_color = vec4(1.00, 0.25, 0.85, 1.0);
uniform float flow_speed = 1.4;
uniform float opacity = 0.92;

void fragment() {
	float along = UV.x;
	float across = UV.y;
	float t = TIME * flow_speed;
	float a = abs(across);
	vec2 uv1 = vec2(along * 0.10 - t * 0.20, across * 0.22);
	vec2 uv2 = vec2(along * 0.22 - t * 0.38 + 0.37, across * 0.5 + 0.21);
	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;
	// proudové pruhy
	float streak = smoothstep(0.55, 0.85, n1 * 0.55 + n2 * 0.6);
	float thin = smoothstep(0.80, 0.97, n2);
	// pulsy letící po proudu
	float pulse = smoothstep(0.82, 1.0, 0.5 + 0.5 * sin(along * 0.9 - TIME * 3.2 + n1 * 5.0));
	float edge = smoothstep(0.55, 1.0, a);
	vec3 col = mix(deep_color.rgb, core_color.rgb * 0.55, (1.0 - a * a) * 0.35 + streak * 0.5);
	col += core_color.rgb * (streak * 0.9 + pulse * 0.8 * (1.0 - a));
	col += accent_color.rgb * thin * 0.9 * (1.0 - a * 0.5);
	col += core_color.rgb * edge * 1.1;
	float fade = 1.0 - smoothstep(0.9, 1.0, a) * 0.75;
	ALBEDO = col * 1.25;
	ALPHA = clamp(opacity * fade, 0.0, 1.0);
}
