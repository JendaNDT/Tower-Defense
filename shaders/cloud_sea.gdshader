shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Souvislé moře oblaků pod ostrovem – NEPRŮHLEDNÉ (bez ALPHA), aby se průhledné objekty (vodopád, voda, efekty) kreslily správně navrch.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 scroll = vec2(0.010, 0.005);
uniform float tile = 0.011;
uniform float coverage = 0.42;
uniform float softness = 0.28;
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 shade_color : source_color = vec4(0.58, 0.69, 0.87, 1.0);
uniform vec4 base_color : source_color = vec4(0.45, 0.66, 0.92, 1.0);
uniform vec2 sun_dir = vec2(0.55, 0.35);

varying vec3 wpos;

float fbm(vec2 p) {
	return texture(noise_tex, p).r * 0.58 + texture(noise_tex, p * 2.3 + vec2(0.17)).r * 0.28 + texture(noise_tex, p * 5.1 + vec2(0.6)).r * 0.14;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * tile + scroll * TIME;
	float n = fbm(p);
	float n_sun = fbm(p + sun_dir * 0.012);
	float density = smoothstep(coverage - 0.02, coverage + softness, n);
	float lit = clamp((n - n_sun) * 9.0 + 0.55, 0.0, 1.0);
	vec3 cloud = mix(shade_color.rgb, light_color.rgb, lit);
	vec3 col = mix(base_color.rgb, cloud, density);
	ALBEDO = col;
}
