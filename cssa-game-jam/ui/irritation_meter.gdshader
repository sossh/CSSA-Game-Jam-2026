shader_type canvas_item;
render_mode unshaded;

// Chunky segmented heat bar to match the pixel HUD. One draw call; animates from TIME and two uniforms.
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 track_color : source_color = vec4(0.01, 0.03, 0.06, 1.0);

const float SEGMENTS = 20.0;

// Flat tier colors, same hues as the HUD (stomach teal up to alarm magenta), no smooth rainbow.
vec3 heat_step(float t) {
	if (t < 0.15) return vec3(0.12, 0.95, 0.72);
	if (t < 0.35) return vec3(0.72, 0.95, 0.30);
	if (t < 0.55) return vec3(1.00, 0.80, 0.22);
	if (t < 0.75) return vec3(1.00, 0.52, 0.14);
	if (t < 0.92) return vec3(1.00, 0.28, 0.20);
	return vec3(1.00, 0.30, 0.85);
}

void fragment() {
	vec2 uv = UV;
	float seg = floor(uv.x * SEGMENTS);
	float seg_x = fract(uv.x * SEGMENTS);
	// Thin gap between blocks.
	float block = step(0.12, seg_x);
	float seg_mid = (seg + 0.5) / SEGMENTS;
	float lit = step(seg_mid, level);
	float danger = smoothstep(0.7, 1.0, level);
	float pulse = step(0.5, fract(TIME * (1.5 + level * 4.0)));

	vec3 fill = heat_step(seg_mid);
	// Top edge highlight like the Stomach bar fill.
	fill = mix(fill, mix(fill, vec3(1.0), 0.6), step(uv.y, 0.14));
	// Last lit block blinks when the teacher is close to snapping.
	float lead = step(abs(seg_mid - level), 0.5 / SEGMENTS + 0.001);
	fill *= 1.0 - danger * lead * pulse * 0.35;
	fill += vec3(1.0) * flash * 0.5;

	vec3 track = track_color.rgb + vec3(0.04) * block;
	COLOR = vec4(mix(track, fill, lit * block), 1.0);
}
