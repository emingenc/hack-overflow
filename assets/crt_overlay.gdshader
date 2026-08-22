shader_type canvas_item;

// Post-processing stack (single pass, compat-safe): whole-screen bloom via LOD
// screen blur + flat scanlines + blue-noise dither + subtle vignette.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.07;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 base = texture(screen_texture, SCREEN_UV).rgb;

	// Whole-screen bloom: radial multi-tap blur (gl_compatibility has no screen
	// mipmaps, so textureLod is a no-op — sample two rings instead).
	vec3 blur = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float ang = float(i) * 6.28318 / 4.0;
		vec2 dir = vec2(cos(ang), sin(ang));
		blur += texture(screen_texture, SCREEN_UV + dir * 0.004).rgb;
		blur += texture(screen_texture, SCREEN_UV + dir * 0.011).rgb;
	}
	vec3 col = base + (blur / 8.0) * bloom_strength;

	// Flat scanlines (LED-panel, no curvature — the 2026 read).
	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(SCREEN_UV.y * 6.28318 * 720.0 / 3.5));

	// Static dither (compat has no debanding); time-invariant so it never boils.
	col += (hash21(floor(SCREEN_UV / SCREEN_PIXEL_SIZE)) - 0.5) * dither_strength / 255.0;

	// Subtle vignette.
	vec2 d = SCREEN_UV - vec2(0.5);
	col *= 1.0 - vignette_strength * dot(d, d) * 1.4;

	COLOR = vec4(col, 1.0);
}
