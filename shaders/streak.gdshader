shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// Světelná stopa za střelou: kužel s osou +Z (hrot vzadu). Jas klesá od střely (z = 0) ke konci (z = len).

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float len = 1.4;
uniform float strength = 1.0;

varying float k;

void vertex() {
	k = clamp(VERTEX.z / max(len, 0.001), 0.0, 1.0);
}

void fragment() {
	float f = 1.0 - k;
	ALBEDO = color.rgb * (0.4 + 1.6 * f * f) * strength;
	ALPHA = f * f * color.a;
}
