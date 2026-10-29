shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Terén létajícího ostrova. Barva se skládá ve fragment shaderu z řídicích textur generovaných v kódu:
//  field_tex: R = vzdálenost od osy cesty, G = vzdálenost od břehu řeky ((sd + 4) / 16)
//  biome_tex: RGBA = váhy biomů (les, louka, poušť, sníh)
// Vertex COLOR.a = 1 pro horní plochu, 0 pro skalnatý útes a spodek (COLOR.rgb = barva skály).

uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform sampler2D biome_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 map_origin = vec2(-36.0, -36.0);
uniform float map_size = 72.0;

varying vec3 w_pos;
varying vec3 w_nrm;

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 xz = w_pos.xz;
	vec2 uvw = clamp((xz - map_origin) / map_size, vec2(0.001), vec2(0.999));
	vec4 f = texture(field_tex, uvw);
	vec4 b = texture(biome_tex, uvw);
	float path_sd = f.r * 16.0 - 4.0;
	float river_sd = f.g * 16.0 - 4.0;

	float n_lo = texture(noise_tex, xz * 0.035).r;
	float n_mid = texture(noise_tex, xz * 0.21 + vec2(0.3)).r;
	float n_hi = texture(noise_tex, xz * 1.1 + vec2(0.7)).r;

	// ---------- barva podle biomu
	vec3 forest = mix(lin(vec3(0.17, 0.40, 0.16)), lin(vec3(0.24, 0.50, 0.19)), n_mid);
	vec3 meadow = mix(lin(vec3(0.42, 0.68, 0.22)), lin(vec3(0.58, 0.80, 0.30)), n_mid);
	float ripple = 0.5 + 0.5 * sin(xz.x * 0.9 + xz.y * 0.55 + n_lo * 9.0);
	vec3 desert = mix(lin(vec3(0.88, 0.72, 0.44)), lin(vec3(0.96, 0.82, 0.54)), ripple * 0.6 + n_mid * 0.4);
	vec3 snow = mix(lin(vec3(0.90, 0.94, 1.0)), lin(vec3(0.99, 0.99, 1.0)), n_mid);
	snow *= 0.96 + 0.06 * sin(n_hi * 12.0);
	vec3 ground = forest * b.r + meadow * b.g + desert * b.b + snow * b.a;
	ground *= 0.9 + 0.2 * n_lo;
	// louka: drobné kvítky
	float fl = smoothstep(0.80, 0.84, n_hi) * b.g;
	vec3 fl_col = mix(lin(vec3(1.0, 0.95, 0.5)), lin(vec3(0.95, 0.55, 0.75)), step(0.5, n_mid));
	ground = mix(ground, fl_col, fl * 0.85);

	// ---------- cesta (udusaná hlína / kamínky)
	float edge_noise = (n_mid - 0.5) * 0.45;
	float path_mask = 1.0 - smoothstep(-0.12, 0.22, path_sd + edge_noise);
	path_mask *= smoothstep(-1.4, -0.2, river_sd);
	vec3 dirt = mix(lin(vec3(0.50, 0.38, 0.26)), lin(vec3(0.63, 0.51, 0.36)), n_hi);
	dirt = mix(dirt, lin(vec3(0.66, 0.62, 0.58)), b.a * 0.5);
	float pebble = smoothstep(0.82, 0.9, n_hi);
	dirt = mix(dirt, lin(vec3(0.70, 0.68, 0.64)), pebble * 0.6);
	float path_rim = smoothstep(-0.05, 0.12, path_sd + edge_noise) * (1.0 - smoothstep(0.12, 0.4, path_sd + edge_noise));
	vec3 col = mix(ground, dirt, path_mask);
	col *= 1.0 - path_rim * 0.18;

	// ---------- břehy řeky a dno
	float bank = 1.0 - smoothstep(0.0, 1.7, river_sd + (n_mid - 0.5) * 0.7);
	vec3 wet = mix(lin(vec3(0.40, 0.33, 0.24)), lin(vec3(0.78, 0.70, 0.52)), smoothstep(0.3, 0.9, n_hi));
	col = mix(col, wet, bank * 0.9);
	float bed = 1.0 - smoothstep(-0.6, 0.0, river_sd);
	col = mix(col, lin(vec3(0.30, 0.36, 0.38)), bed * 0.8);

	// ---------- plošiny kopců (field_tex.b: 0.5 kopec, 1.0 vrchol): světlejší vyšlapaná zem s kamenným lemem
	float plateau = smoothstep(0.40, 0.48, f.b);
	float summit = smoothstep(0.78, 0.96, f.b);
	float hill_rim = (1.0 - smoothstep(0.0, 0.035, abs(f.b - 0.44))) * 0.6 + (1.0 - smoothstep(0.0, 0.05, abs(f.b - 0.87))) * 0.5;
	col = mix(col, lin(vec3(0.66, 0.62, 0.54)), plateau * 0.20 + summit * 0.12);
	col *= 1.0 - hill_rim * 0.14;

	// ---------- skála na svazích
	float slope = 1.0 - clamp(w_nrm.y, 0.0, 1.0);
	float strata = 0.5 + 0.5 * sin(w_pos.y * 2.4 + n_lo * 6.0);
	vec3 rock = lin(vec3(0.50, 0.46, 0.43)) * (0.8 + 0.3 * strata) * (0.9 + 0.2 * n_mid);
	float rock_mask = smoothstep(0.30, 0.55, slope + (n_lo - 0.5) * 0.18);
	col = mix(col, rock, rock_mask);

	// ---------- útes a spodek (vertex COLOR.a = 0)
	vec3 belly = lin(COLOR.rgb) * (0.75 + 0.35 * strata) * (0.88 + 0.24 * n_mid);
	float depth_f = clamp(-w_pos.y / 28.0, 0.0, 1.0);
	belly = mix(belly, lin(vec3(0.72, 0.82, 0.96)), depth_f * depth_f * 0.65);
	col = mix(belly, col, COLOR.a);

	ALBEDO = col;
	// spodek a útes jsou ve stínu ostrova: odražené světlo z oblaků (jemná vlastní svítivost, nahoru ne)
	EMISSION = belly * (1.0 - COLOR.a) * 0.5 * mix(lin(vec3(1.0, 0.95, 0.9)), lin(vec3(0.8, 0.9, 1.0)), depth_f);
	ROUGHNESS = mix(0.95, 0.55, b.a * COLOR.a * (1.0 - rock_mask));
	SPECULAR = 0.25;
}
