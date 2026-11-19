// Die VEREDELUNG als SCHMALE FASSUNG (Spieler-Wahl 2026-11-19): das Material
// selbst leuchtet satt von innen, Edelmetall fasst zwei gegenueberliegende
// Ecken - ungleich gross, mit eingezogener Kante. Kein Ring, kein Quadrat:
// die gehoeren den Runen. Die Mitte bleibt der Ziffer.

uniform vec3 vivid = vec3(1.0);
uniform vec3 mount = vec3(1.0, 0.80, 0.26);
uniform float glow = 1.0;
uniform float core_gain = 1.3;
uniform float mount_gain = 1.2;
uniform float alpha_amount = 1.0;

varying vec3 tview;

const float CAP_BIG = 0.50;
const float CAP_SMALL = 0.39;
const float CAP_CURVE = 0.78;

float aa_below(float edge, float v) {
	float e = fwidth(v) * 1.2 + 0.0005;
	return 1.0 - smoothstep(edge - e, edge + e, v);
}

// Fassung in einer Ecke: 0 am Scheitel, 1 auf der eingezogenen Kante.
float cap_field(vec2 p, float r) {
	vec2 q = max(p, vec2(0.0)) / r;
	return pow(q.x, CAP_CURVE) + pow(q.y, CAP_CURVE);
}

void dope_mount(vec2 uv, vec3 tv, out vec3 albedo, out vec3 emission,
		out float metal, out float rough, out float alpha) {
	// Glut: heller Kern knapp neben der Mitte, satte Farbe, tiefer Rand.
	float r = length(uv - vec2(0.46, 0.44));
	vec3 col = mix(vivid, vivid * 0.62, smoothstep(0.45, 0.80, r));
	float core = 1.0 - smoothstep(0.0, 0.42, r);
	vec3 hot = mix(col, mix(vivid, vec3(1.0), 0.55), core * 0.6);
	// EIN Lichtstreif, der beim Drehen wandert - Politur statt Muster.
	float sweep = exp(-pow(((uv.x + uv.y) * 0.5 - 0.36 - tv.x * 0.22) * 12.0, 2.0));

	float big = cap_field(uv, CAP_BIG);
	float small = cap_field(vec2(1.0) - uv, CAP_SMALL);
	float in_big = aa_below(1.0, big);
	float in_small = aa_below(1.0, small);
	float band = max(in_big, in_small);
	float f = mix(small, big, step(in_small, in_big));
	// Heller Scheitel, dunkle eingezogene Kante: die Fassung liest als Koerper.
	vec3 metal_col = mount * mix(1.25, 0.6, smoothstep(0.0, 1.0, f));
	metal_col *= 1.0 - 0.55 * smoothstep(0.88, 1.0, f);

	albedo = mix(hot + vec3(0.2) * sweep, metal_col, band);
	emission = mix(hot * glow * (1.0 + core * (core_gain - 1.0)) + vivid * sweep * 0.25,
		metal_col * mount_gain, band);
	metal = mix(0.1, 0.85, band);
	rough = mix(0.08, 0.22, band);
	alpha = max(alpha_amount, band);
}
