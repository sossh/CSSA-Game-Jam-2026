shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Measure both axes in viewport heights so the corners keep their shape.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 point = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 half_size = vec2(aspect * 0.5 + 0.002, 0.505);
	float radius = UV.y < 0.5 ? 0.18 : 0.20;
	vec2 corner = abs(point) - half_size + vec2(radius);
	float distance_to_opening = length(max(corner, vec2(0.0)))
		+ min(max(corner.x, corner.y), 0.0) - radius;

	float aa = SCREEN_PIXEL_SIZE.y * 1.2;
	float rim = smoothstep(-aa, aa, distance_to_opening);
	float shadow = smoothstep(-0.012, 0.0, distance_to_opening) * 0.42;
	float shell = smoothstep(0.007, 0.010, distance_to_opening);
	float raised_edge = smoothstep(0.010, 0.023, distance_to_opening)
		* (1.0 - smoothstep(0.031, 0.057, distance_to_opening));
	float seam = smoothstep(0.043, 0.045, distance_to_opening)
		* (1.0 - smoothstep(0.046, 0.048, distance_to_opening));

	vec3 gasket = mix(vec3(0.038, 0.059, 0.081), vec3(0.23, 0.31, 0.38),
		smoothstep(0.001, 0.007, distance_to_opening));
	vec3 enamel = mix(vec3(0.46, 0.53, 0.60), vec3(0.73, 0.79, 0.84), 1.0 - UV.y);
	enamel = mix(enamel, vec3(0.91, 0.94, 0.97), raised_edge * (0.85 - UV.y * 0.34));
	enamel *= 1.0 - seam * 0.26;
	COLOR = vec4(mix(gasket, enamel, shell), max(rim, shadow));
}
