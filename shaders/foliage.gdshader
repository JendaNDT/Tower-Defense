shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Stromy, tráva, květiny: houpání ve větru (síla roste s výškou), mírná variace odstínu podle polohy.
// Funguje i pro MultiMesh – směr větru se převádí ze světa do prostoru instance.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float height_ref = 4.0;
uniform float wind_strength = 0.12;
uniform float flutter = 0.03;
uniform vec2 wind_dir = vec2(0.8, 0.6);

varying float v_tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float h2 = h * h;
	float gust = textureLod(noise_tex, origin.xz * 0.025 + wind_dir * TIME * 0.05, 0.0).r;
	float phase = origin.x * 0.6 + origin.z * 0.45;
	float sway = sin(TIME * 1.3 + phase) * (0.35 + gust * 1.1) * wind_strength * h2;
	float lean = (gust - 0.4) * wind_strength * 1.5 * h2;
	vec3 off_world = vec3(wind_dir.x, 0.0, wind_dir.y) * (sway + lean);
	off_world += vec3(sin(TIME * 3.7 + VERTEX.y * 5.0 + phase * 2.0), 0.0, cos(TIME * 3.1 + VERTEX.x * 6.0 + phase)) * flutter * h;
	mat3 m = mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz);
	VERTEX += inverse(m) * off_world;
	v_tint = 0.88 + 0.24 * fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2)) * v_tint;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = c * COLOR.a;
}
