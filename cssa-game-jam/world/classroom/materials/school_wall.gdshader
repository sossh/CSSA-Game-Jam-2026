shader_type spatial;

// Repaints the School Kit wall atlas as a two-tone classroom wall.
// Dark texels (charcoal skirting, timber trims) keep the kit texture; the noisy
// plaster becomes clean paint with a faint trace of the original stains.
// Painted bands use world height, so scaled wall modules line up with each other.

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 upper_paint : source_color = vec3(0.7, 0.67, 0.6);
uniform vec3 dado_paint : source_color = vec3(0.35, 0.46, 0.42);
uniform vec3 rail_color : source_color = vec3(0.3, 0.22, 0.15);
uniform float dado_height = 1.15;
uniform float rail_width = 0.07;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.35;

varying float world_height;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 kit = texture(atlas, UV).rgb;
	float luminance = dot(kit, vec3(0.299, 0.587, 0.114));
	float plaster = smoothstep(0.34, 0.44, luminance);
	float blend = fwidth(world_height);
	float upper = smoothstep(dado_height - blend, dado_height + blend, world_height);
	vec3 paint = mix(dado_paint, upper_paint, upper);
	float rail = 1.0 - smoothstep(rail_width * 0.5 - blend, rail_width * 0.5 + blend, abs(world_height - dado_height));
	paint = mix(paint, rail_color, rail);
	paint *= 1.0 + (luminance - 0.62) * stain_strength;
	ALBEDO = mix(kit, paint, plaster);
	ROUGHNESS = mix(0.92, 0.55, rail);
	SPECULAR = 0.2;
}
