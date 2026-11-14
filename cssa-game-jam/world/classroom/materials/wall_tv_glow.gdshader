shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Soft light bleed on the wall around the lobby TV. One transparent quad.

uniform vec3 glow_color : source_color = vec3(0.55, 0.8, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	float a = smoothstep(1.0, 0.0, d);
	ALBEDO = glow_color;
	ALPHA = a * a * strength;
}
