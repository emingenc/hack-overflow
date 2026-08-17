shader_type canvas_item;
// Professional neon button: radial-gradient sphere, inner glow ring,
// drop shadow, and press feedback — for touch control buttons.

uniform vec4 base_color : source_color = vec4(0.1, 0.7, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float pressed : hint_range(0.0, 1.0) = 0.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float radius = 0.5;

	// Disc mask with soft edge
	float disc = smoothstep(radius, radius - 0.03, dist);
	if (disc <= 0.001) {
		// Outside the button: faint outer glow only
		float outer_glow = smoothstep(radius + 0.18, radius, dist) * 0.35;
		COLOR = vec4(glow_color.rgb, outer_glow);
	} else {

	// Radial gradient: brighter at top-left (light source), darker at bottom-right
	float light = 1.0 - (dist / radius) * 0.55;
	light += (0.5 - uv.y) * 0.25; // top-lit
	vec3 sphere = base_color.rgb * (0.55 + 0.45 * light);

	// Specular highlight (small bright spot top-left)
	float spec = smoothstep(0.42, 0.10, dist) * smoothstep(0.30, 0.10, uv.y + 0.18);
	sphere += vec3(1.0) * spec * 0.85;

	// Inner glow ring
	float ring = smoothstep(0.40, 0.47, dist) * smoothstep(0.55, 0.47, dist);
	sphere += glow_color.rgb * ring * 1.4;

	// Press feedback: darken + slight scale illusion
	sphere *= 1.0 - pressed * 0.35;
	sphere += glow_color.rgb * hover * 0.15;

	// Edge darkening (anti-aliased rim)
	sphere *= 1.0 - smoothstep(0.42, 0.50, dist) * 0.25;

	COLOR = vec4(sphere, disc);
	}
}
