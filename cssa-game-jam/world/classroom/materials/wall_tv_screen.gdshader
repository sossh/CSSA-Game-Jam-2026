shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Cheap "old classroom TV" look for the lobby blooper reel. One texture
// sample set, no extra passes, no lights. Letterboxes any aspect ratio.

uniform sampler2D media : source_color, filter_linear, repeat_disable;
uniform float media_aspect = 1.7778;
uniform float screen_aspect = 1.7778;
uniform float has_media : hint_range(0.0, 1.0) = 0.0;
uniform float static_amount : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.09;
uniform float scanline_count = 110.0;
uniform float curvature : hint_range(0.0, 0.3) = 0.06;
uniform float brightness = 1.05;
uniform float flicker : hint_range(0.0, 0.1) = 0.02;

const vec3 BARS[7] = vec3[7](
	vec3(0.75, 0.75, 0.75),
	vec3(0.75, 0.75, 0.0),
	vec3(0.0, 0.75, 0.75),
	vec3(0.0, 0.75, 0.0),
	vec3(0.75, 0.0, 0.75),
	vec3(0.75, 0.0, 0.0),
	vec3(0.0, 0.0, 0.75)
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	c *= 1.0 + curvature * dot(c, c) * 4.0;
	vec2 suv = c + 0.5;
	float on_glass = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);

	vec3 col;
	if (has_media > 0.5) {
		vec2 p = c;
		float r = media_aspect / screen_aspect;
		if (r > 1.0) {
			p.y *= r;
		} else {
			p.x /= r;
		}
		vec2 muv = p + 0.5;
		float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
		// RGB split only shows up while the channel is glitching between clips.
		float split = static_amount * 0.012;
		col = vec3(
			texture(media, muv + vec2(split, 0.0)).r,
			texture(media, muv).g,
			texture(media, muv - vec2(split, 0.0)).b
		) * inside;
	} else {
		col = BARS[int(clamp(suv.x * 7.0, 0.0, 6.0))] * 0.9;
		col *= mix(1.0, 0.45, step(0.82, suv.y));
	}

	// Slow rolling hum bar.
	float hum = smoothstep(0.1, 0.0, abs(fract(suv.y - TIME * 0.06) - 0.5));
	col *= 1.0 - 0.07 * hum;

	// Channel static (between clips, or a faint hiss with no signal).
	float n = hash(floor(suv * vec2(240.0, 135.0)) + floor(TIME * 30.0));
	col = mix(col, vec3(n), static_amount);

	// Scanlines, vignette, mains flicker.
	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(suv.y * scanline_count * 6.28318));
	col *= mix(0.5, 1.0, smoothstep(0.78, 0.25, length(c)));
	col *= 1.0 + flicker * sin(TIME * 60.0);

	// Blinking REC lamp, top left (the "REC" text is a Label3D beside it).
	vec2 d = (suv - vec2(0.06, 0.1)) * vec2(screen_aspect, 1.0);
	float lamp = smoothstep(0.034, 0.028, length(d)) * step(0.5, fract(TIME * 0.9));
	col = mix(col, vec3(1.0, 0.08, 0.06), lamp);

	ALBEDO = col * brightness * on_glass;
}
