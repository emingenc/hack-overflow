shader_type canvas_item;

// Matrix digital rain — one fullscreen ColorRect, one shader, no atlas.
// Per-column speed/phase via hash; glyphs are procedural (varied stems/bars/ticks)
// so the effect needs no font/runtime texture and works headless.
uniform vec2 resolution = vec2(1280.0, 720.0);
uniform vec2 cell_px = vec2(26.0, 22.0);   // on-screen size of one rain cell
uniform float speed = 70.0;                // px/sec base fall
uniform float max_alpha = 0.65;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 pix = UV * resolution;
	vec2 cell = floor(pix / cell_px);
	vec2 cuv = fract(pix / cell_px);            // 0..1 within the cell

	float s = speed * (0.4 + 0.9 * hash21(cell + 1.7));   // per-column speed
	float ph = hash21(cell + 9.3) * 30.0;                 // per-column phase
	float head = fract(-TIME * s / cell_px.y + ph);       // 0=head .. 1=tail
	float trail = smoothstep(0.0, 0.10, head) * smoothstep(1.0, 0.40, head);

	// Varied procedural glyph seeded per cell.
	float gtype = floor(hash21(cell + 6.2) * 4.0);        // 0..3
	float xoff = (hash21(cell + 2.9) - 0.5) * 0.4;        // stem x jitter
	float stem = step(abs(cuv.x - (0.5 + xoff)), 0.06);
	float bar  = step(abs(cuv.y - 0.5), 0.06) * step(abs(cuv.x - (0.5 + xoff)), 0.20);
	float ticks = 0.0;
	for (int k = 0; k < 2; k++) {
		float th = hash21(cell + float(k) * 7.31);
		float tw = hash21(cell + float(k) * 3.17);
		ticks += step(abs(cuv.y - th), 0.05) * step(abs(cuv.x - (0.5 + xoff)), 0.06 + tw * 0.22);
	}
	float g;
	if (gtype < 1.0)      { g = stem; }
	else if (gtype < 2.0) { g = bar; }
	else if (gtype < 3.0) { g = clamp(stem + ticks, 0.0, 1.0); }
	else                  { g = clamp(bar + step(abs(cuv.x - (0.7 + xoff)), 0.05), 0.0, 1.0); }

	// Head glyph glows bright white-green; trail fades to dim green.
	vec3 col = mix(vec3(0.02, 0.35, 0.18), vec3(0.8, 1.0, 0.7), smoothstep(0.88, 1.0, head));
	col *= g * trail * max_alpha;
	COLOR = vec4(col, col.g * 0.9);
}
