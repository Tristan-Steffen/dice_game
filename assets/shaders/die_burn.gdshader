shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// DURCHGEBRANNT = ASCHE (Spieler-Wahl 2026-09-07 aus Ruß, Risse, Asche, Verkohlt,
// Geschmolzen): die Seite ist zu hellgrauer Asche ausgebrannt, flockig, mit
// dunklen Bruchlinien - die Blitz-Maschine der Ladung, EINGEFROREN. EIN Quad je
// Seite zwischen Runen-Auflage und Ziffer (die Ziffer bleibt lesbar - der Würfel
// zählt für die Hand). Alphagemischt: sie DECKT, sie leuchtet nicht.

#include "res://assets/shaders/die_lightning.gdshaderinc"

uniform float face_seed = 0.0;

const vec3 ASH = vec3(0.64, 0.62, 0.6);
const vec3 DUST = vec3(0.16, 0.15, 0.15);
const float COVER = 0.78;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wert-Rauschen und drei Oktaven davon.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.2;
}

// Die Bruchlinien der Seite: zwei Bahnen von Kante zu Kante, je ein Ast.
float cracks(vec2 p, float seed) {
	float best = 1e9;
	for (int c = 0; c < 2; c++) {
		float cs = seed + float(c) * 53.0;
		vec2 a;
		vec2 b;
		rim_pair(cs, a, b);
		vec2 knot;
		best = min(best, bolt_dist(p, a, b, 8, 0.22, cs, 0.0, 3 + int(hash11(cs + 7.0) * 3.0), knot));
		vec2 tip = branch_tip(knot, normalize(b - a), 0.5, cs + 8.0);
		vec2 dummy;
		best = min(best, bolt_dist(p, knot, tip, 5, 0.3, cs + 40.0, 0.0, 99, dummy));
	}
	return best;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float px = length(fwidth(p));
	float grain = fbm(p * 2.4 + vec2(face_seed * 1.7, face_seed * 0.9));
	float fine = noise(p * 40.0 + face_seed);
	float cd = cracks(p, face_seed * 13.7);
	vec3 col = ASH * (0.8 + 0.4 * grain) * (0.9 + 0.2 * fine);
	float flake = 1.0 - smoothstep(0.0, max(0.03, px * 2.0), cd);
	ALBEDO = mix(col, DUST, flake * 0.8);
	ALPHA = COVER;
}
