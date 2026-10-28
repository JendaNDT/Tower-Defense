shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Modely poskládané v kódu (MeshKit): barva vrcholu = albedo (sRGB), alfa vrcholu = síla emise.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);   // rgb = barva přebarvení, a = míra
uniform float emission_mul = 1.0;
uniform float flash = 0.0;                                      // bílý záblesk po zásahu
uniform float roughness_v : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	base = mix(base, tint.rgb, tint.a);
	ALBEDO = base;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
	EMISSION = base * COLOR.a * emission_mul + vec3(flash);
}
