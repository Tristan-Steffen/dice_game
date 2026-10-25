// Die VEREDELUNG einer Seite: je Material EINE eigene, gleichmaessige Geometrie
// (Spieler-Entscheid 2026-10-25) - prozedural gerechnet, darum ohne Textur und
// in jeder Entfernung scharf. Die LINIEN leuchten, das Feld bleibt dunkel;
// dark_lines kehrt es um (Knochen ritzt sie ein, er leuchtet nie).
// field_glow traegt den Koerper als EMISSION: am Tisch liegt kein Licht ausser
// dem schwachen Ambient, eine Seite bringt ihr Aussehen also selbst mit.

uniform int kind = 0;
uniform vec3 body = vec3(1.0);
uniform vec3 light = vec3(1.0);
uniform float gain = 1.0;
uniform float cells = 4.0;
uniform float width = 0.014;
uniform float dark_lines = 0.0;
uniform float shade_amount = 0.0;
uniform float field_glow = 0.55;
uniform float metallic_amount = 0.0;
uniform float roughness_amount = 0.1;
uniform float alpha_amount = 1.0;

varying vec3 tview;

const int KIND_FACETS = 0;   // Rubin
const int KIND_COMB = 1;     // Bernstein
const int KIND_RINGS = 2;    // Gold
const int KIND_HATCH = 3;    // Knochen
const int KIND_STEPS = 4;    // Glas
const int KIND_CIRCUIT = 5;  // Kupfer

float aa_line(float d, float w) {
	float e = fwidth(d) * 1.2 + 0.0005;
	return 1.0 - smoothstep(w - e, w + e, d);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// FACETTEN (Rubin): Voronoi-Zellen, der Schliff eines Steins. Erst die naechste
// Zelle suchen, dann den Abstand zu ihren Raendern - die Kanten des Schliffs.
float facet_distance(vec2 uv, out float shade) {
	vec2 x = uv * cells;
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float t = dot(r, r);
			if (t < md) { md = t; mr = r; mg = g; }
		}
	}
	shade = hash1(n + mg);
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			vec2 diff = r - mr;
			if (dot(diff, diff) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(diff)));
			}
		}
	}
	return md / cells;
}

// WABEN (Bernstein): zwei versetzte Gitter, das naehere gewinnt - Sechsecke.
float comb_distance(vec2 uv, out float shade) {
	vec2 p = uv * cells;
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(gv);
	float hex = max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
	shade = hash1(floor((p - gv) * 4.0));
	return (0.5 - hex) / cells;
}

// RAUTEN (Knochen): Kreuzschraffur aus zwei Diagonalfamilien.
float hatch_distance(vec2 uv) {
	float u = fract((uv.x + uv.y) * cells);
	float v = fract((uv.x - uv.y) * cells);
	return min(min(u, 1.0 - u), min(v, 1.0 - v)) / (cells * 1.4142);
}

// STUFEN (Glas): konzentrische Quadrate, der Stufenschliff im Kristall.
float step_distance(vec2 uv) {
	float br = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
	float t = fract(br * cells);
	return min(t, 1.0 - t) / (cells * 2.0);
}

// LEITERBAHN (Kupfer): orthogonales Netz um 45 Grad gedreht, mit Knoten an
// jeder Kreuzung - der Leiter.
float circuit_distance(vec2 uv) {
	vec2 p = uv * cells;
	vec2 c = fract(vec2(p.x + p.y, p.x - p.y) * 0.7071);
	vec2 e = min(c, 1.0 - c) / cells;
	float node = length(min(c, 1.0 - c)) / cells;
	return min(min(e.x, e.y), abs(node - width * 2.2));
}

// RINGE (Gold): konzentrische Ringe einer Praegung.
float ring_distance(vec2 uv) {
	float t = fract(length(uv - vec2(0.5)) * 2.0 * cells);
	return min(t, 1.0 - t) / (cells * 2.0);
}

// Golds Muenzrand: feine Riffelung auf dem aeusseren Saum.
float coin_reed(vec2 uv) {
	float br = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
	float along = abs(uv.x - 0.5) > abs(uv.y - 0.5) ? uv.y : uv.x;
	return smoothstep(0.80, 0.86, br) * (0.5 + 0.5 * cos(along * 150.0));
}

void dope_lattice(vec2 uv, vec3 tv, out vec3 albedo, out vec3 emission,
		out float metal, out float rough, out float alpha) {
	float d = 1.0;
	float shade = 1.0;
	float sheen = 0.0;   // Golds Streiflicht und Riffelrand auf der Albedo
	float spark = 0.0;   // ... und dasselbe in der Emission
	float matte = 0.0;   // ... und wie matt der Rest daneben liegt
	if (kind == KIND_FACETS) {
		d = facet_distance(uv, shade);
	} else if (kind == KIND_COMB) {
		d = comb_distance(uv, shade);
	} else if (kind == KIND_RINGS) {
		d = ring_distance(uv);
		// Das Streiflicht WANDERT beim Drehen: tangentialer Blickwinkel statt UV.
		float sweep = exp(-pow(((uv.x - uv.y) * 0.707 - tv.x * 0.35) * 3.0, 2.0));
		float reed = coin_reed(uv);
		sheen = 0.30 * sweep + 0.25 * reed;
		spark = 0.18 * sweep + 0.30 * reed;
		matte = 0.30 * (1.0 - sweep);
	} else if (kind == KIND_HATCH) {
		d = hatch_distance(uv);
	} else if (kind == KIND_STEPS) {
		d = step_distance(uv);
	} else {
		d = circuit_distance(uv);
	}
	float on_line = aa_line(d, width);
	float glow = mix(on_line, 1.0 - on_line, dark_lines);
	vec3 field = body * mix(1.0, 1.0 - 0.80 * on_line, dark_lines)
		* (1.0 - shade_amount + shade_amount * shade);
	albedo = field + body * sheen;
	emission = light * (glow + spark) * gain + field * field_glow;
	metal = metallic_amount;
	rough = roughness_amount + matte;
	alpha = alpha_amount;
}
