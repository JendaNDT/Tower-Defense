shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
// Tekoucí řeka. UV.x = vzdálenost po toku (m), UV.y = -1..1 napříč. Mesh má tangenty (tangent = směr toku).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 deep_color : source_color = vec4(0.04, 0.32, 0.50, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.78, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flow_speed = 1.4;
uniform float opacity = 0.84;
uniform float ripple = 4.0;

void fragment() {
	float along = UV.x;
	float across = UV.y;
	float t = TIME * flow_speed;
	vec2 uv1 = vec2(along * 0.16 - t * 0.16, across * 0.30);
	vec2 uv2 = vec2(along * 0.09 - t * 0.12 + 0.37, across * 0.45 + 0.21);
	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;

	float e = 0.006;
	float gx = texture(noise_tex, uv1 + vec2(e, 0.0)).r - texture(noise_tex, uv1 - vec2(e, 0.0)).r;
	float gy = texture(noise_tex, uv1 + vec2(0.0, e)).r - texture(noise_tex, uv1 - vec2(0.0, e)).r;
	float hx = texture(noise_tex, uv2 + vec2(e, 0.0)).r - texture(noise_tex, uv2 - vec2(e, 0.0)).r;
	float hy = texture(noise_tex, uv2 + vec2(0.0, e)).r - texture(noise_tex, uv2 - vec2(0.0, e)).r;
	NORMAL_MAP = vec3(0.5 + (gx + hx) * ripple, 0.5 + (gy + hy) * ripple, 1.0);
	NORMAL_MAP_DEPTH = 1.0;

	float a = abs(across);
	float edge = smoothstep(0.55, 1.0, a);
	float center = 1.0 - a * a;
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, center * 0.9);
	float streak = smoothstep(0.62, 0.9, n1 * 0.6 + n2 * 0.55);
	float foam = clamp(edge * (0.45 + n2) * 0.9 + streak * 0.35, 0.0, 1.0);
	foam *= smoothstep(0.25, 0.75, n1 + 0.25);
	// pohyblivé pěnové vlnky těsně u břehu
	float wave = 0.5 + 0.5 * sin(along * 1.7 - TIME * 2.1 + n1 * 6.0 + across * 3.0);
	float shore = smoothstep(0.72, 0.97, a) * (1.0 - smoothstep(0.985, 1.0, a));
	foam = clamp(foam + shore * (0.35 + 0.55 * wave) * (0.55 + n2), 0.0, 1.0);

	ALBEDO = mix(col, foam_color.rgb, foam);
	ROUGHNESS = mix(0.05, 0.7, foam);
	SPECULAR = 0.8;
	METALLIC = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.55, 0.75, 1.0) * fres * 0.35;
	ALPHA = clamp(mix(opacity, 1.0, foam), 0.0, 1.0) * (1.0 - smoothstep(0.9, 1.0, a) * 0.7);
}
