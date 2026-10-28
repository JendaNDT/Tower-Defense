shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Ukazatel zdraví nad nepřítelem (billboard, QuadMesh o poměru stran ~ 7:1).

uniform float fill = 1.0;

void vertex() {
	vec3 scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(scl.x, 0.0, 0.0, 0.0), vec4(0.0, scl.y, 0.0, 0.0), vec4(0.0, 0.0, scl.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV;
	float border_x = 0.03;
	float border_y = 0.2;
	bool inside = uv.x > border_x && uv.x < 1.0 - border_x && uv.y > border_y && uv.y < 1.0 - border_y;
	float rel = (uv.x - border_x) / (1.0 - 2.0 * border_x);
	vec3 col_full = mix(vec3(0.95, 0.15, 0.10), vec3(0.25, 0.9, 0.2), smoothstep(0.15, 0.7, fill));
	vec3 col = vec3(0.04, 0.04, 0.05);
	if (inside) {
		col = rel <= fill ? col_full : vec3(0.18, 0.05, 0.05);
	}
	ALBEDO = col;
	ALPHA = 0.95;
}
