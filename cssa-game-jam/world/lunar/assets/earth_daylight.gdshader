shader_type spatial;
render_mode unshaded;

uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 sunlight_direction = vec3(0.88, 0.35, 0.32);
uniform float daylight = 1.25;
uniform float reflected_light = 0.19;
uniform vec3 atmosphere_color : source_color = vec3(0.24, 0.52, 0.96);
uniform float atmosphere_strength = 0.26;

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 toward_sun = normalize(mat3(VIEW_MATRIX) * sunlight_direction);
	float sun_angle = max(dot(normal, toward_sun), 0.0);
	float illumination = reflected_light + daylight * sun_angle;
	vec3 surface = texture(surface_color, UV).rgb * illumination;
	float limb = pow(1.0 - clamp(dot(normal, normalize(VIEW)), 0.0, 1.0), 3.5);
	float scatter = limb * smoothstep(0.0, 0.7, sun_angle);
	ALBEDO = surface + atmosphere_color * atmosphere_strength * scatter;
}
