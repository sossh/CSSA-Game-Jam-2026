shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float desaturation : hint_range(0.0, 1.0) = 0.92;
uniform vec4 tint_color : source_color = vec4(0.48, 0.52, 0.60, 1.0);
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.75;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	float gray = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(gray) * tint_color.rgb * 1.5;
	vec3 desaturated = mix(screen_col.rgb, grayscale, desaturation);

	vec2 uv = SCREEN_UV - vec2(0.5);
	float dist = length(uv);
	float vignette = clamp(1.0 - dist * vignette_strength, 0.0, 1.0);

	COLOR = vec4(desaturated * vignette, COLOR.a);
}
