shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Měkký stín pod postavou / věží (jedna MultiMesh pro všechny). Síla stínu = barva instance (alfa).

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = 1.0 - smoothstep(0.15, 1.0, d);
	ALBEDO = vec3(0.02, 0.03, 0.05);
	ALPHA = a * a * COLOR.a;
}
