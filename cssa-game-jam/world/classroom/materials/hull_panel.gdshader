shader_type spatial;

// World-space panel cladding, so scaled boxes share one seam grid.

uniform vec3 base_color : source_color = vec3(0.78, 0.79, 0.8);
uniform vec3 seam_color : source_color = vec3(0.16, 0.17, 0.19);
uniform vec3 band_color : source_color = vec3(0.85, 0.58, 0.14);
uniform vec3 dust_color : source_color = vec3(0.42, 0.41, 0.39);
uniform vec2 panel_size = vec2(1.5, 1.25);
uniform float seam_width = 0.03;
uniform float band_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float band_bottom = 0.15;
uniform float band_top = 0.6;
uniform float dust_bottom = -0.5;
uniform float dust_top = 1.4;
uniform float dust_strength : hint_range(0.0, 1.0) = 0.5;
uniform float variation : hint_range(0.0, 0.3) = 0.05;
uniform float metal : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	vec2 cell = p / panel_size;
	vec2 f = fract(cell);
	vec2 aa = fwidth(cell);
	vec2 sw = seam_width / panel_size;
	vec2 edge = smoothstep(sw - aa, sw + aa, f) * smoothstep(sw - aa, sw + aa, 1.0 - f);
	float panel = edge.x * edge.y;
	float h = hash(floor(cell));

	vec3 col = base_color * (1.0 + (h - 0.5) * variation * 2.0);
	float ya = fwidth(world_pos.y);
	float band = band_enabled * smoothstep(band_bottom - ya, band_bottom + ya, world_pos.y)
			* (1.0 - smoothstep(band_top - ya, band_top + ya, world_pos.y));
	col = mix(col, band_color, band);
	float dust = (1.0 - smoothstep(dust_bottom, dust_top, world_pos.y)) * dust_strength;
	col = mix(col, dust_color, dust);
	col = mix(seam_color, col, panel);

	ALBEDO = col;
	METALLIC = metal * panel * (1.0 - dust);
	ROUGHNESS = mix(0.85, 0.5 + h * 0.2, panel);
}
