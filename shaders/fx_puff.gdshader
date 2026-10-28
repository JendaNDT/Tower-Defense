shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Měkký kulatý billboard (dým, jiskry, sníh, mlha). Funguje i pro GPUParticles3D (barva částice = COLOR).

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float glow = 0.0;
uniform float softness = 1.0;

varying vec4 pcol;

void vertex() {
	pcol = COLOR;
	vec3 scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(scl.x, 0.0, 0.0, 0.0), vec4(0.0, scl.y, 0.0, 0.0), vec4(0.0, 0.0, scl.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = 1.0 - smoothstep(1.0 - softness * 0.95, 1.0, d);
	ALBEDO = color.rgb * pcol.rgb * (1.0 + glow);
	ALPHA = a * alpha * color.a * pcol.a;
}
