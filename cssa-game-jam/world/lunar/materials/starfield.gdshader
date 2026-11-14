shader_type sky;

uniform vec3 space_color : source_color = vec3(0.002, 0.0025, 0.005);
uniform vec3 band_color : source_color = vec3(0.05, 0.055, 0.07);
uniform vec3 band_axis = vec3(0.35, 0.82, -0.45);
uniform float band_width = 0.22;
uniform float star_brightness = 1.6;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 star_layer(vec3 dir, float scale, float keep, float radius) {
	vec3 p = dir * scale;
	vec3 id = floor(p);
	float h = hash(id);
	if (h < keep) {
		return vec3(0.0);
	}
	vec3 offset = vec3(hash(id + 13.1), hash(id + 41.7), hash(id + 71.3)) * 0.6 + 0.2;
	float d = length(fract(p) - offset);
	float level = (h - keep) / (1.0 - keep);
	float glow = smoothstep(radius, 0.0, d) * mix(0.25, 1.0, level * level);
	float temp = hash(id + 5.3);
	vec3 tint = temp < 0.2 ? vec3(1.0, 0.82, 0.66) : (temp > 0.85 ? vec3(0.72, 0.82, 1.0) : vec3(1.0));
	return tint * glow;
}

float soft_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 stars = star_layer(dir, 90.0, 0.94, 0.16) * 1.4 + star_layer(dir, 210.0, 0.9, 0.22) * 0.55;
	float lane = dot(dir, normalize(band_axis));
	float clouds = soft_noise(dir * 5.0) * 0.6 + soft_noise(dir * 13.0) * 0.4;
	float band = exp(-lane * lane / (band_width * band_width)) * smoothstep(0.25, 0.85, clouds);
	stars += star_layer(dir, 380.0, 0.82, 0.25) * 0.5 * band;
	COLOR = space_color + band_color * band + stars * star_brightness;
}
