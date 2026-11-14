shader_type spatial;
render_mode cull_disabled;

uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec3 light_dust : source_color = vec3(0.5, 0.49, 0.475);
uniform vec3 dark_dust : source_color = vec3(0.33, 0.33, 0.33);
uniform vec3 rock_color : source_color = vec3(0.25, 0.245, 0.24);
uniform float macro_scale = 0.013;
uniform float mid_scale = 0.09;
uniform float fine_scale = 0.6;
uniform float bump_strength = 0.35;
uniform float slope_start = 0.18;
uniform float slope_end = 0.45;

varying vec3 world_pos;
varying float slope;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope = 1.0 - abs(dot(normalize(NORMAL), normalize(VERTEX)));
}

void fragment() {
	vec2 p = world_pos.xz;
	float macro = texture(grain, p * macro_scale).r;
	float mid = texture(grain, p * mid_scale + 0.37).r;
	float fine = texture(grain, p * fine_scale + 0.71).r;

	vec3 col = mix(dark_dust, light_dust, smoothstep(0.3, 0.7, macro * 0.65 + mid * 0.35));
	col = mix(col, rock_color, smoothstep(slope_start, slope_end, slope + (mid - 0.5) * 0.15));
	col *= 0.93 + fine * 0.14;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;

	float height = fine * 0.6 + mid * 0.4;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump_strength * grad);
}
