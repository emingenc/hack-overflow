shader_type canvas_item;

// CRT scanline + vignette overlay for the terminal/cyberpunk look.
// Renders ONLY dark scanlines/vignette on a TRANSPARENT base — never white.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float flicker : hint_range(0.0, 1.0) = 0.03;
uniform vec2 resolution = vec2(1280.0, 720.0);

void fragment() {
	vec2 uv = UV;

	// Scanlines (dark bars, transparent elsewhere)
	float scanline = sin(uv.y * resolution.y * 0.5) * 0.5 + 0.5;
	float alpha = scanline_strength * scanline;

	// Vignette (darken corners, transparent center)
	vec2 dist = uv - vec2(0.5);
	float vig = vignette_strength * dot(dist, dist) * 2.5;
	alpha += vig;

	// Subtle flicker on the darkening
	float time_flicker = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 24.0));

	// Black overlay at computed alpha; game pixels show through everywhere else.
	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha * time_flicker, 0.0, 0.45));
}
