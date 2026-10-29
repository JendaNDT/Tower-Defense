shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Pozadí pod stanicí: hluboký vesmír s mlhovinou a hvězdami ve dvou vrstvách (pomalu se posouvají). NEPRŮHLEDNÉ.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 scroll = vec2(0.004, 0.002);
uniform float tile = 0.0085;
uniform vec4 space_color : source_color = vec4(0.012, 0.016, 0.055, 1.0);
uniform vec4 nebula_a : source_color = vec4(0.30, 0.08, 0.55, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.04, 0.42, 0.62, 1.0);
uniform vec4 nebula_c : source_color = vec4(0.75, 0.15, 0.50, 1.0);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float star_layer(vec2 p, float density, float size, float seed) {
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(id + seed);
	if (h < density) {
		return 0.0;
	}
	vec2 off = vec2(hash(id + seed + 1.7), hash(id + seed + 9.3)) - 0.5;
	float d = length(f - off * 0.7);
	float tw = 0.65 + 0.35 * sin(TIME * (1.2 + h * 3.0) + h * 40.0);
	float k = (h - density) / (1.0 - density);
	return (1.0 - smoothstep(0.0, size, d)) * tw * (0.35 + 0.65 * k);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * tile + scroll * TIME;
	float n1 = texture(noise_tex, p).r;
	float n2 = texture(noise_tex, p * 2.1 + vec2(0.31, 0.77)).r;
	float n3 = texture(noise_tex, p * 0.45 + vec2(0.55, 0.12)).r;
	float neb = smoothstep(0.38, 0.85, n1 * 0.6 + n2 * 0.4);
	float neb2 = smoothstep(0.45, 0.9, n3);
	vec3 col = space_color.rgb;
	col += nebula_a.rgb * neb * 0.50;
	col += nebula_b.rgb * neb2 * 0.45 * (0.4 + n2);
	col += nebula_c.rgb * smoothstep(0.62, 0.95, n1 * n2 * 1.9) * 0.40;
	// hvězdy: tři hloubky
	vec2 sp = wpos.xz;
	float s = star_layer(sp * 0.55 + scroll * TIME * 40.0, 0.88, 0.22, 3.0) * 1.0
		+ star_layer(sp * 0.27 + scroll * TIME * 22.0 + 7.0, 0.90, 0.26, 11.0) * 1.3
		+ star_layer(sp * 1.1 + scroll * TIME * 70.0 + 3.0, 0.93, 0.18, 19.0) * 0.8;
	vec3 star_col = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.85, 0.7), hash(floor(sp * 0.55) + 5.0));
	col += star_col * s * 1.6;
	ALBEDO = col;
}
