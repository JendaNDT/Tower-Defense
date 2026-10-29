shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Terén vesmírné stanice (sci-fi motiv). Stejné řídicí textury jako terrain.gdshader:
//  field_tex: R = vzdálenost od osy cesty, G = vzdálenost od břehu energetické řeky ((sd + 4) / 16)
//  biome_tex: RGBA = váhy biomů (bio-džungle, neonová pole, rudá pustina, kryo plošina)
// Vertex COLOR.a = 1 pro horní plochu, 0 pro útes a spodek asteroidu.

uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform sampler2D biome_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 map_origin = vec2(-36.0, -36.0);
uniform float map_size = 72.0;
uniform vec3 glow_a : source_color = vec3(0.10, 0.90, 1.00);
uniform vec3 glow_b : source_color = vec3(1.00, 0.20, 0.80);

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
	vec3 forest = mix(lin(vec3(0.05, 0.17, 0.21)), lin(vec3(0.09, 0.30, 0.27)), n_mid);
	vec3 meadow = mix(lin(vec3(0.08, 0.38, 0.33)), lin(vec3(0.20, 0.58, 0.42)), n_mid);
	float ripple = 0.5 + 0.5 * sin(xz.x * 0.9 + xz.y * 0.55 + n_lo * 9.0);
	vec3 desert = mix(lin(vec3(0.58, 0.26, 0.16)), lin(vec3(0.80, 0.43, 0.24)), ripple * 0.6 + n_mid * 0.4);
	vec3 snow = mix(lin(vec3(0.74, 0.88, 1.0)), lin(vec3(0.92, 0.97, 1.0)), n_mid);
	// praskliny v ledu
	float crack = (1.0 - smoothstep(0.0, 0.012, abs(n_hi - 0.5))) * b.a;
	snow = mix(snow, lin(vec3(0.35, 0.60, 0.85)), crack * 0.8);
	vec3 ground = forest * b.r + meadow * b.g + desert * b.b + snow * b.a;
	ground *= 0.9 + 0.2 * n_lo;
	// zářící spóry a krystalky
	float spore = smoothstep(0.83, 0.87, n_hi);
	vec3 spore_col = mix(glow_a, glow_b, step(0.5, n_mid));
	ground = mix(ground, spore_col * 0.5, spore * (b.r * 0.8 + b.g * 0.9));
	vec3 emit = spore_col * spore * (b.r * 0.9 + b.g * 0.9) * (0.7 + 0.3 * sin(TIME * 1.6 + n_lo * 30.0)) * 0.9;
	emit += glow_a * crack * 0.45;
	// pustina: žhnoucí žilky v písku
	float ember = smoothstep(0.90, 0.94, n_hi) * b.b;
	emit += vec3(1.0, 0.45, 0.12) * ember * 0.8;

	// ---------- cesta: tmavá ocelová dlažba s tenkými svítícími okraji
	float edge_noise = (n_mid - 0.5) * 0.12;
	float path_mask = 1.0 - smoothstep(-0.12, 0.22, path_sd + edge_noise);
	path_mask *= smoothstep(-1.4, -0.2, river_sd);
	vec2 tile = xz * 0.85;
	vec2 tf = abs(fract(tile) - 0.5);
	float seam = smoothstep(0.455, 0.49, max(tf.x, tf.y));
	vec3 plate = mix(lin(vec3(0.27, 0.31, 0.40)), lin(vec3(0.38, 0.43, 0.53)), n_hi);
	plate = mix(plate, lin(vec3(0.09, 0.10, 0.15)), seam * 0.8);
	vec3 col = mix(ground, plate, path_mask);
	float edge_line = smoothstep(-0.20, -0.12, path_sd) * (1.0 - smoothstep(-0.10, -0.02, path_sd));
	float pulse = 0.55 + 0.45 * sin(TIME * 2.2 - (xz.x + xz.y) * 0.45);
	emit += glow_a * edge_line * path_mask * (0.9 + 0.8 * pulse);

	// ---------- břehy energetické řeky: tmavý kov se světelným lemem
	float bank = 1.0 - smoothstep(0.0, 1.5, river_sd + (n_mid - 0.5) * 0.5);
	vec3 metal = mix(lin(vec3(0.10, 0.12, 0.17)), lin(vec3(0.20, 0.23, 0.30)), smoothstep(0.3, 0.9, n_hi));
	col = mix(col, metal, bank * 0.9);
	float bank_glow = (1.0 - smoothstep(0.15, 0.55, abs(river_sd - 0.45))) * smoothstep(-0.4, 0.2, river_sd);
	emit += mix(glow_a, glow_b, 0.25) * bank_glow * 0.7;
	float bed = 1.0 - smoothstep(-0.6, 0.0, river_sd);
	col = mix(col, lin(vec3(0.03, 0.05, 0.10)), bed * 0.9);

	// ---------- skála na svazích: tmavý čedič se žilkami
	float slope = 1.0 - clamp(w_nrm.y, 0.0, 1.0);
	float strata = 0.5 + 0.5 * sin(w_pos.y * 2.4 + n_lo * 6.0);
	vec3 rock = lin(vec3(0.17, 0.16, 0.23)) * (0.8 + 0.3 * strata) * (0.9 + 0.2 * n_mid);
	float rock_mask = smoothstep(0.30, 0.55, slope + (n_lo - 0.5) * 0.18);
	col = mix(col, rock, rock_mask);
	float vein = (1.0 - smoothstep(0.0, 0.015, abs(n_hi - 0.62))) * rock_mask;
	emit += glow_b * vein * 0.9;
	emit *= 1.0 - rock_mask * 0.4;

	// ---------- útes a spodek asteroidu (vertex COLOR.a = 0)
	float depth_f = clamp(-w_pos.y / 28.0, 0.0, 1.0);
	vec3 belly = lin(vec3(0.11, 0.12, 0.17)) * (0.75 + 0.45 * strata) * (0.85 + 0.3 * n_mid);
	belly = mix(belly, lin(vec3(0.05, 0.07, 0.16)), depth_f * 0.7);
	// svítící pásy (žíly energie) kolem celého spodku
	float band = 1.0 - smoothstep(0.0, 0.05, abs(fract(w_pos.y * 0.21 + n_lo * 2.4) - 0.5));
	float band2 = 1.0 - smoothstep(0.0, 0.035, abs(fract(w_pos.y * 0.13 + n_mid * 1.7 + 0.37) - 0.5));
	vec3 belly_emit = glow_a * band * (0.8 + 0.5 * sin(TIME * 1.1 + w_pos.x * 0.3)) + glow_b * band2 * 0.8;
	belly_emit *= 1.0 - depth_f * 0.5;
	col = mix(belly, col, COLOR.a);
	emit = mix(belly_emit, emit, COLOR.a);

	ALBEDO = col;
	EMISSION = emit + belly * (1.0 - COLOR.a) * 0.35 * lin(vec3(0.7, 0.8, 1.0));
	ROUGHNESS = mix(0.8, 0.45, path_mask) * mix(1.0, 0.7, b.a * (1.0 - path_mask));
	METALLIC = path_mask * 0.35 * COLOR.a + bank * 0.3;
	SPECULAR = 0.3;
}
