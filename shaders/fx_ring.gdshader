shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Rozpínající se prstenec / vlna na zemi (mrazový pulz, výbuch). Velikost řídí scale uzlu.

uniform vec4 color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float thickness = 0.16;
uniform float fill = 0.22;
uniform float glow = 0.4;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = smoothstep(1.0 - thickness, 1.0 - thickness * 0.35, d) * (1.0 - smoothstep(0.96, 1.0, d));
	float inner = (1.0 - smoothstep(0.0, 1.0, d)) * fill * step(d, 1.0);
	ALBEDO = color.rgb * (1.0 + glow);
	ALPHA = clamp(ring + inner, 0.0, 1.0) * alpha * color.a;
}
