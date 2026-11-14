shader_type spatial;

uniform vec3 stripe_color : source_color = vec3(0.86, 0.64, 0.12);
uniform vec3 gap_color : source_color = vec3(0.08, 0.08, 0.09);
uniform float stripe_width = 0.18;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float t = (p.x + p.y) / (stripe_width * 2.0);
	float aa = fwidth(t);
	float s = smoothstep(0.5 - aa, 0.5 + aa, fract(t)) - smoothstep(1.0 - aa, 1.0, fract(t));
	ALBEDO = mix(stripe_color, gap_color, s);
	ROUGHNESS = 0.6;
}
