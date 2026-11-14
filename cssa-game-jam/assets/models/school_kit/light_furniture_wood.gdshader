shader_type spatial;
render_mode cull_disabled;

uniform sampler2D wood_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float wood_roughness = 0.8;

void fragment() {
	vec3 grain = texture(wood_atlas, UV).rgb;
	ALBEDO = pow(grain, vec3(0.55)) * vec3(0.78, 0.65, 0.49);
	ROUGHNESS = wood_roughness;
	SPECULAR = 0.25;
}
