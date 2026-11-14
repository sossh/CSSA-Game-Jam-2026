shader_type canvas_item;
render_mode unshaded;

// Thermometer-style heat bar. One draw call; everything animates from TIME and two uniforms.
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 track_color : source_color = vec4(0.015, 0.04, 0.07, 1.0);

vec3 heat_ramp(float t) {
	vec3 c0 = vec3(0.20, 0.95, 0.62);
	vec3 c1 = vec3(0.95, 0.90, 0.22);
	vec3 c2 = vec3(1.00, 0.52, 0.10);
	vec3 c3 = vec3(1.00, 0.14, 0.16);
	vec3 c4 = vec3(1.00, 0.30, 0.85);
	if (t < 0.33) return mix(c0, c1, t / 0.33);
	if (t < 0.66) return mix(c1, c2, (t - 0.33) / 0.33);
	if (t < 0.92) return mix(c2, c3, (t - 0.66) / 0.26);
	return mix(c3, c4, (t - 0.92) / 0.08);
}

void fragment() {
	vec2 uv = UV;
	float speed = 2.0 + level * 9.0;
	float wave = sin(uv.x * 26.0 - TIME * speed + sin(uv.y * 7.0 + TIME * 2.3) * 1.6) * 0.5 + 0.5;
	float inside = smoothstep(level, level - 0.006, uv.x);
	float danger = smoothstep(0.7, 1.0, level);
	float pulse = 0.5 + 0.5 * sin(TIME * (5.0 + level * 16.0));

	vec3 fill = heat_ramp(uv.x) * (0.72 + 0.4 * wave);
	// Diagonal hazard stripes crawl across the fill once the teacher is close to snapping.
	float stripes = step(0.5, fract((uv.x * 14.0 - uv.y * 2.5) - TIME * 0.8));
	fill = mix(fill, fill * 0.55, stripes * danger * 0.8);
	fill += vec3(1.0, 0.85, 0.5) * exp(-abs(uv.x - level) * 38.0) * (0.55 + 0.45 * pulse);
	fill += vec3(1.0) * flash * 0.55;
	fill *= 1.0 + danger * pulse * 0.25;
	// Top gloss.
	fill += vec3(0.18) * smoothstep(0.5, 0.0, uv.y);

	float tick = step(0.985, fract(uv.x * 5.0 + 0.001)) * 0.12;
	vec3 track = track_color.rgb + vec3(tick);
	COLOR = vec4(mix(track, fill, inside), 1.0);
}
