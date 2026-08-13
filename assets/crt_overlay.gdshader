shader_type canvas_item;

// CRT scanline + vignette overlay for the terminal/cyberpunk look.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float flicker : hint_range(0.0, 1.0) = 0.04;
uniform vec2 resolution = vec2(1280.0, 720.0);

void fragment() {
	vec2 uv = UV;
	vec3 color = texture(TEXTURE, uv).rgb;

	// Scanlines
	float scanline = sin(uv.y * resolution.y * 0.5) * 0.5 + 0.5;
	color *= 1.0 - scanline_strength * scanline;

	// Subtle flicker
	float time_flicker = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 24.0));
	color *= time_flicker;

	// Vignette
	vec2 dist = uv - vec2(0.5);
	float vig = 1.0 - vignette_strength * dot(dist, dist) * 2.5;
	color *= vig;

	COLOR = vec4(color, 1.0);
}
